<script setup lang="ts">
  import * as d3 from "d3";
  import { onMounted, onUnmounted, ref, watch, computed } from "vue";
  import type { DerivationGraph, Node } from "../types/types";

  const props = defineProps<{ graph: DerivationGraph }>();

  const svgRef = ref<SVGSVGElement | null>(null);
  const selectedNodeId = ref<number | null>(null);
  const searchQuery = ref("");

  let zoomBehavior: d3.ZoomBehavior<SVGSVGElement, unknown>;
  let zoomLayer: d3.Selection<SVGGElement, unknown, null, undefined>;
  let nodePositions = new Map<number, { x: number; y: number }>();

  const sidebarWidth = ref(384);
  const isResizing = ref(false);
  const isSidepaneFullScreen = ref(false);

  function toggleFullScreen() {
    isSidepaneFullScreen.value = !isSidepaneFullScreen.value;
  }

  function startResize() {
    isResizing.value = true;
    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("mouseup", stopResize);
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }

  function handleMouseMove(e: MouseEvent) {
    if (!isResizing.value) return;
    const newWidth = window.innerWidth - e.clientX;
    if (newWidth > 200 && newWidth < window.innerWidth * 0.9) {
      sidebarWidth.value = newWidth;
    }
  }

  function stopResize() {
    isResizing.value = false;
    document.removeEventListener("mousemove", handleMouseMove);
    document.removeEventListener("mouseup", stopResize);
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  }

  onUnmounted(() => stopResize());

  /* ---------- Derived data ---------- */
  const selectedNode = computed(() =>
    props.graph.nodes.find(n => n.id === selectedNodeId.value) ?? null
  );

  const parentNode = computed(() => {
    if (!selectedNode.value) return null;
    const link = props.graph.links.find(l => l.target === selectedNode.value.id);
    return link ? props.graph.nodes.find(n => n.id === link.source) ?? null : null;
  });

  const childNodes = computed(() => {
    if (!selectedNode.value) return [];
    return props.graph.links
      .filter(l => l.source === selectedNode.value!.id) // TODO: unsafe
      .map(l => props.graph.nodes.find(n => n.id === l.target))
      .filter(Boolean) as Node[];
  });

  const searchResults = computed(() => {
    if (!searchQuery.value) return [];
    const q = Number(searchQuery.value);
    return isNaN(q) ? [] : props.graph.nodes.filter(n => n.id === q);
  });

  /* ---------- Graph rendering ---------- */
  function renderGraph(graph: DerivationGraph) {
    if (!svgRef.value) return;

    const width = svgRef.value.clientWidth || window.innerWidth;
    const height = svgRef.value.clientHeight || window.innerHeight;

    d3.select(svgRef.value).selectAll("*").remove();
    const svg = d3.select(svgRef.value).attr("viewBox", `0 0 ${width} ${height}`);

    // Create the zoom layer WITHOUT a global stroke to keep text crisp
    zoomLayer = svg.append("g");

    zoomBehavior = d3.zoom<SVGSVGElement, unknown>()
      .scaleExtent([0.01, 4])
      .on("zoom", (event) => zoomLayer.attr("transform", event.transform));

    svg.call(zoomBehavior);

    const rootNode = d3.stratify<Node>()
      .id(d => d.id.toString())
      .parentId(d => {
        const parent = graph.links.find(l => l.target === d.id);
        return parent ? parent.source.toString() : null;
      })(graph.nodes);

    const treeLayout = d3.tree<Node>().nodeSize([200, 120]);
    const hierarchyRoot = treeLayout(rootNode)

    const maxY = d3.max(hierarchyRoot.descendants(), d => d.y) ?? 0;

    nodePositions.clear();
    hierarchyRoot.descendants().forEach(d => nodePositions.set(d.data.id, { x: d.x, y: maxY - d.y }));

    zoomLayer.append("g")
      .attr("stroke", "#d1d5db")
      .attr("stroke-width", 1.2)
      .selectAll("line")
      .data(hierarchyRoot.links())
      .enter()
      .append("line")
      .attr("x1", d => d.source.x)
      .attr("y1", d => maxY - d.source.y)
      .attr("x2", d => d.target.x)
      .attr("y2", d => maxY - d.target.y);

    const nodes = zoomLayer.append("g")
      .selectAll("g")
      .data(hierarchyRoot.descendants())
      .enter()
      .append("g")
      .attr("transform", d => `translate(${d.x}, ${maxY - d.y})`)
      .on("click", (_, d) => selectNode(d.data.id));

    nodes.append("rect")
      .attr("x", -85)
      .attr("y", -20)
      .attr("width", 170)
      .attr("height", 40)
      .attr("rx", 2)
      .attr("fill", d => d.data.id === selectedNodeId.value ? "#f3f0f7" : "#ffffff")
      .attr("stroke", d => d.data.id === selectedNodeId.value ? "#5e5184" : "#ccc")
      .attr("stroke-width", d => (d.data.id === selectedNodeId.value ? 2 : 1));

    nodes.append("text")
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .attr("font-size", 11)
      .attr("fill", "#333") // Clean dark grey text
      .attr("stroke", "none") // Ensure no stroke makes text blurry
      .text(d => `#${d.data.id}: ${d.data.rule}`);
  }

  function selectNode(id: number) {
    selectedNodeId.value = id;
    focusNode(id);
    renderGraph(props.graph);
  }

  function focusNode(id: number) {
    if (!svgRef.value || !nodePositions.has(id)) return;
    const pos = nodePositions.get(id)!;
    const scale = 1.2;
    const tx = svgRef.value.clientWidth / 2 - pos.x * scale;
    const ty = svgRef.value.clientHeight / 2 - pos.y * scale;

    d3.select(svgRef.value).transition().duration(500)
      .call(zoomBehavior.transform, d3.zoomIdentity.translate(tx, ty).scale(scale));
  }

  onMounted(() => renderGraph(props.graph));
  watch(() => props.graph, renderGraph, { deep: true });
</script>

<template>
  <div class="flex w-screen h-screen overflow-hidden relative font-sans text-[#333]">
    <svg ref="svgRef" class="flex-1 h-full bg-white" />

    <div
      v-if="!isSidepaneFullScreen"
      class="w-1 cursor-col-resize hover:bg-[#5e5184] transition-colors bg-gray-200 z-10 flex-shrink-0"
      @mousedown="startResize"
    ></div>

    <aside
      :style="{ width: isSidepaneFullScreen ? '100vw' : sidebarWidth + 'px' }"
      class="h-full bg-white border-l border-gray-300 overflow-y-auto flex-shrink-0 transition-all duration-300"
      :class="{ 'absolute right-0 top-0 z-20 shadow-2xl': isSidepaneFullScreen }"
    >
      <div class="p-4 border-b border-gray-100 flex justify-between items-center bg-[#fafafa]">
        <h1 class="font-bold text-[#5e5184] text-lg tracking-tight">Derivation</h1>
        <button
          @click="toggleFullScreen"
          class="px-3 py-1 bg-white border border-gray-300 hover:border-[#5e5184] hover:text-[#5e5184] rounded text-[10px] font-bold uppercase transition-all shadow-sm"
        >
          {{ isSidepaneFullScreen ? 'Exit Full' : 'Full Screen' }}
        </button>
      </div>

      <div class="p-6">
        <div class="mb-8">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search by ID..."
            class="w-full px-3 py-2 border border-gray-300 rounded bg-[#fcfcfc] focus:ring-1 focus:ring-[#5e5184] outline-none"
          />
        </div>

        <div v-if="selectedNode">
          <div class="flex text-[#8f59a1] font-bold text-xs justify-between mb-6">
            <button :disabled="selectedNodeId === 0" class="hover:underline disabled:opacity-30 cursor-pointer" @click="selectNode(selectedNodeId - 1)">
              « PREV NODE
            </button>
            <button :disabled="selectedNodeId === props.graph.nodes.length - 1" class="hover:underline disabled:opacity-30 cursor-pointer" @click="selectNode(selectedNodeId + 1)">
              NEXT NODE »
            </button>
          </div>

          <h2 class="font-bold mb-4 text-2xl text-[#5e5184]">
            Node #{{ selectedNode.id }}
          </h2>

          <div class="mb-6">
            <div class="bg-[#f5f5f5] p-4 rounded border border-gray-200">
              <span class="text-[10px] font-bold text-gray-400 tracking-widest block mb-2 uppercase">Rule Identifier</span>
              <code class="text-[#5e5184] font-mono font-bold">{{ selectedNode.rule }}</code>
            </div>
          </div>

          <div class="mb-8">
            <span class="text-[10px] font-bold text-gray-400 tracking-widest block mb-2 uppercase">Visualization</span>
            <div class="bg-white border border-gray-200 rounded p-4 flex justify-center shadow-sm">
              <img
                src="../src/data/IXXArg.svg"
                alt="Rule Diagram"
                class="max-w-full h-auto"
              />
              </div>
          </div>

          <div v-if="selectedNode.data.length" class="space-y-8">
            <div v-for="(item, index) in selectedNode.data" :key="index">
              <h3 class="text-xs font-bold text-[#5e5184] border-b border-gray-100 pb-1 mb-3 tracking-wider">
                {{ item.label }}
              </h3>
              <pre class="p-4 bg-[#f8f8f8] rounded text-sm font-mono overflow-x-auto border border-gray-200 leading-relaxed whitespace-pre-wrap">{{ item.content }}</pre>
            </div>
          </div>

          <nav class="mt-12 pt-6 border-t border-gray-200 space-y-4 text-[#8f59a1] font-medium">
            <button v-if="parentNode" class="hover:underline flex items-center" @click="selectNode(parentNode.id)">
              <span class="mr-2">↑</span> Parent: #{{ parentNode.id }}
            </button>
            <div v-if="childNodes.length">
              <span class="text-gray-400 text-[10px] font-bold uppercase tracking-widest block mb-2">Children</span>
              <ul class="space-y-2">
                <li v-for="child in childNodes" :key="child.id">
                  <button @click="selectNode(child.id)" class="hover:underline">
                    • #{{ child.id }} ({{ child.rule }})
                  </button>
                </li>
              </ul>
            </div>
          </nav>
        </div>

        <div v-else class="text-center py-20 text-gray-400 italic">
          Select a node in the graph to view details
        </div>
      </div>
    </aside>
  </div>
</template>
