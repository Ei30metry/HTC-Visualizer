import { z } from "zod";

/** A directed edge between nodes */
export const LinkSchema = z.object({
  source: z.number(),
  target: z.number(),
});

export const NodeDataSchema = z.object({
  label: z.string(),
  content: z.string(),
});

/** A single node in the derivation graph */
export const NodeSchema = z.object({
  id: z.number(),
  rule: z.string(),
  data: z.array(NodeDataSchema),
  children: z.array(z.number()),
});

/** Root object */
export const DerivationGraphSchema = z.object({
  nodes: z.array(NodeSchema),
  links: z.array(LinkSchema),
});

export type Link = z.infer<typeof LinkSchema>;
export type Node = z.infer<typeof NodeSchema>;
export type DerivationGraph = z.infer<typeof DerivationGraphSchema>;