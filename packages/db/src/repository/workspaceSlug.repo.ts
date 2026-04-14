import { eq } from "drizzle-orm";

import type { dbClient } from "@kan/db/client";
import { slugs } from "@kan/db/schema";

export const getWorkspaceSlug = (db: dbClient, slug: string) => {
  return db.query.slugs.findFirst({
    columns: {
      slug: true,
      type: true,
    },
    where: eq(slugs.slug, slug),
  });
};

export const createWorkspaceSlugCheck = (
  _db: dbClient,
  _input: {
    slug: string;
    userId: string;
    available: boolean;
    reserved: boolean;
  },
) => {
  // Slug check tracking disabled - not needed for basic functionality
  return Promise.resolve();
};
