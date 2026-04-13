-- Kan Database Setup Script for Supabase
-- This script contains all migrations to set up Kan for your marketing team
-- Execute this in your Supabase SQL editor to initialize the database

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUM types
CREATE TYPE "public"."board_visibility" AS ENUM('private', 'public');
CREATE TYPE "public"."card_activity_type" AS ENUM('card.created', 'card.updated.title', 'card.updated.description', 'card.updated.index', 'card.updated.list', 'card.updated.label.added', 'card.updated.label.removed', 'card.updated.member.added', 'card.updated.member.removed', 'card.updated.comment.added', 'card.updated.comment.updated', 'card.updated.comment.deleted', 'card.archived', 'card.updated.due_date', 'checklist.created', 'checklist.updated', 'checklist.item.added', 'checklist.item.updated');
CREATE TYPE "public"."source" AS ENUM('trello');
CREATE TYPE "public"."status" AS ENUM('started', 'success', 'failed');
CREATE TYPE "public"."role" AS ENUM('admin', 'member', 'guest');
CREATE TYPE "public"."member_status" AS ENUM('invited', 'active', 'removed', 'paused');
CREATE TYPE "public"."slug_type" AS ENUM('reserved', 'premium');
CREATE TYPE "public"."workspace_plan" AS ENUM('free', 'pro', 'enterprise', 'team');

-- Core Auth Tables
CREATE TABLE IF NOT EXISTS "account" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "accountId" text NOT NULL,
  "providerId" text NOT NULL,
  "userId" uuid NOT NULL,
  "accessToken" text,
  "refreshToken" text,
  "idToken" text,
  "accessTokenExpiresAt" timestamp,
  "refreshTokenExpiresAt" timestamp,
  "scope" text,
  "password" text,
  "createdAt" timestamp NOT NULL,
  "updatedAt" timestamp NOT NULL
);
ALTER TABLE "account" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "session" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "expiresAt" timestamp NOT NULL,
  "token" text NOT NULL,
  "createdAt" timestamp NOT NULL,
  "updatedAt" timestamp NOT NULL,
  "ipAddress" text,
  "userAgent" text,
  "userId" uuid NOT NULL,
  CONSTRAINT "session_token_unique" UNIQUE("token")
);
ALTER TABLE "session" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "verification" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "identifier" text NOT NULL,
  "value" text NOT NULL,
  "expiresAt" timestamp NOT NULL,
  "createdAt" timestamp,
  "updatedAt" timestamp
);
ALTER TABLE "verification" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "apiKey" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "name" text,
  "start" text,
  "prefix" text,
  "key" text NOT NULL,
  "userId" uuid NOT NULL,
  "refillInterval" integer,
  "refillAmount" integer,
  "lastRefillAt" timestamp,
  "enabled" boolean,
  "rateLimitEnabled" boolean,
  "rateLimitTimeWindow" integer,
  "rateLimitMax" integer,
  "requestCount" integer,
  "remaining" integer,
  "lastRequest" timestamp,
  "expiresAt" timestamp,
  "createdAt" timestamp NOT NULL,
  "updatedAt" timestamp NOT NULL,
  "permissions" text,
  "metadata" text
);
ALTER TABLE "apiKey" ENABLE ROW LEVEL SECURITY;

-- User Table
CREATE TABLE IF NOT EXISTS "user" (
  "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
  "name" varchar(255),
  "email" varchar(255) NOT NULL,
  "emailVerified" boolean NOT NULL,
  "image" varchar(255),
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp DEFAULT now() NOT NULL,
  "stripeCustomerId" varchar(255),
  CONSTRAINT "user_email_unique" UNIQUE("email")
);
ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;

-- Workspace Tables
CREATE TABLE IF NOT EXISTS "workspace" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "name" varchar(255) NOT NULL,
  "description" text,
  "slug" varchar(255) NOT NULL,
  "plan" "workspace_plan" DEFAULT 'free' NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "showEmailsToMembers" boolean DEFAULT false,
  "weekStartDay" integer DEFAULT 0,
  CONSTRAINT "workspace_publicId_unique" UNIQUE("publicId"),
  CONSTRAINT "workspace_slug_unique" UNIQUE("slug")
);
ALTER TABLE "workspace" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "workspace_slugs" (
  "slug" varchar(255) NOT NULL,
  "type" "slug_type" NOT NULL,
  CONSTRAINT "workspace_slugs_slug_unique" UNIQUE("slug")
);

CREATE TABLE IF NOT EXISTS "workspace_members" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "userId" uuid,
  "workspaceId" bigint NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "role" "role" NOT NULL,
  "status" "member_status" DEFAULT 'invited' NOT NULL,
  "email" varchar(255),
  CONSTRAINT "workspace_members_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "workspace_members" ENABLE ROW LEVEL SECURITY;

-- Import Table
CREATE TABLE IF NOT EXISTS "import" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "source" "source" NOT NULL,
  "status" "status" NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  CONSTRAINT "import_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "import" ENABLE ROW LEVEL SECURITY;

-- Board Tables
CREATE TABLE IF NOT EXISTS "board" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "name" varchar(255) NOT NULL,
  "description" text,
  "slug" varchar(255) NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "importId" bigint,
  "workspaceId" bigint NOT NULL,
  "visibility" "board_visibility" DEFAULT 'private' NOT NULL,
  "type" varchar(50) DEFAULT 'kanban',
  "sourceId" varchar(255),
  "isArchived" boolean DEFAULT false,
  CONSTRAINT "board_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "board" ENABLE ROW LEVEL SECURITY;

-- List (Column) Tables
CREATE TABLE IF NOT EXISTS "list" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "name" varchar(255) NOT NULL,
  "index" integer NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "boardId" bigint NOT NULL,
  "importId" bigint,
  CONSTRAINT "list_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "list" ENABLE ROW LEVEL SECURITY;

-- Card Tables
CREATE TABLE IF NOT EXISTS "card" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "title" text NOT NULL,
  "description" text,
  "index" integer NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "listId" bigint NOT NULL,
  "importId" bigint,
  "sourceId" varchar(255),
  "dueDate" timestamp,
  CONSTRAINT "card_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "card" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "_card_workspace_members" (
  "cardId" bigint NOT NULL,
  "workspaceMemberId" bigint NOT NULL,
  CONSTRAINT "_card_workspace_members_cardId_workspaceMemberId_pk" PRIMARY KEY("cardId","workspaceMemberId")
);
ALTER TABLE "_card_workspace_members" ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS "_card_labels" (
  "cardId" bigint NOT NULL,
  "labelId" bigint NOT NULL,
  CONSTRAINT "_card_labels_cardId_labelId_pk" PRIMARY KEY("cardId","labelId")
);
ALTER TABLE "_card_labels" ENABLE ROW LEVEL SECURITY;

-- Label Table
CREATE TABLE IF NOT EXISTS "label" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "name" varchar(255) NOT NULL,
  "colourCode" varchar(12),
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  "boardId" bigint NOT NULL,
  "importId" bigint,
  CONSTRAINT "label_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "label" ENABLE ROW LEVEL SECURITY;

-- Card Comments Table
CREATE TABLE IF NOT EXISTS "card_comments" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "comment" text NOT NULL,
  "cardId" bigint NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "deletedAt" timestamp,
  "deletedBy" uuid,
  CONSTRAINT "card_comments_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "card_comments" ENABLE ROW LEVEL SECURITY;

-- Card Activity Table
CREATE TABLE IF NOT EXISTS "card_activity" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "type" "card_activity_type" NOT NULL,
  "cardId" bigint NOT NULL,
  "fromIndex" integer,
  "toIndex" integer,
  "fromListId" bigint,
  "toListId" bigint,
  "labelId" bigint,
  "workspaceMemberId" bigint,
  "fromTitle" varchar(255),
  "toTitle" varchar(255),
  "fromDescription" text,
  "toDescription" text,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "commentId" bigint,
  "fromComment" text,
  "toComment" text,
  "attachmentId" bigint,
  "boardSourceId" varchar(255),
  CONSTRAINT "card_activity_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "card_activity" ENABLE ROW LEVEL SECURITY;

-- Card Attachments Table
CREATE TABLE IF NOT EXISTS "card_attachments" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "cardId" bigint NOT NULL,
  "url" text NOT NULL,
  "name" text,
  "size" bigint,
  "type" varchar(255),
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  CONSTRAINT "card_attachments_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "card_attachments" ENABLE ROW LEVEL SECURITY;

-- User Board Favorites Table
CREATE TABLE IF NOT EXISTS "user_board_favorites" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "userId" uuid NOT NULL,
  "boardId" bigint NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  CONSTRAINT "user_board_favorites_userId_boardId_unique" UNIQUE("userId","boardId")
);
ALTER TABLE "user_board_favorites" ENABLE ROW LEVEL SECURITY;

-- Notifications Table
CREATE TABLE IF NOT EXISTS "notifications" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "userId" uuid NOT NULL,
  "type" varchar(255) NOT NULL,
  "title" text,
  "message" text,
  "cardId" bigint,
  "boardId" bigint,
  "read" boolean DEFAULT false,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  CONSTRAINT "notifications_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "notifications" ENABLE ROW LEVEL SECURITY;

-- Integrations Table
CREATE TABLE IF NOT EXISTS "integrations" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "type" varchar(255) NOT NULL,
  "workspaceId" bigint NOT NULL,
  "config" text,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  CONSTRAINT "integrations_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "integrations" ENABLE ROW LEVEL SECURITY;

-- Workspace Webhooks Table
CREATE TABLE IF NOT EXISTS "workspace_webhooks" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "publicId" varchar(12) NOT NULL,
  "workspaceId" bigint NOT NULL,
  "url" text NOT NULL,
  "events" text NOT NULL,
  "active" boolean DEFAULT true,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  CONSTRAINT "workspace_webhooks_publicId_unique" UNIQUE("publicId")
);
ALTER TABLE "workspace_webhooks" ENABLE ROW LEVEL SECURITY;

-- Feedback Table
CREATE TABLE IF NOT EXISTS "feedback" (
  "id" bigserial PRIMARY KEY NOT NULL,
  "feedback" text NOT NULL,
  "createdBy" uuid NOT NULL,
  "createdAt" timestamp DEFAULT now() NOT NULL,
  "updatedAt" timestamp,
  "url" text NOT NULL,
  "reviewed" boolean DEFAULT false NOT NULL
);
ALTER TABLE "feedback" ENABLE ROW LEVEL SECURITY;

-- Foreign Key Constraints
DO $$ BEGIN
 ALTER TABLE "account" ADD CONSTRAINT "account_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "apiKey" ADD CONSTRAINT "apiKey_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "session" ADD CONSTRAINT "session_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "board" ADD CONSTRAINT "board_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "board" ADD CONSTRAINT "board_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "board" ADD CONSTRAINT "board_importId_import_id_fk" FOREIGN KEY ("importId") REFERENCES "public"."import"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "board" ADD CONSTRAINT "board_workspaceId_workspace_id_fk" FOREIGN KEY ("workspaceId") REFERENCES "public"."workspace"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_fromListId_list_id_fk" FOREIGN KEY ("fromListId") REFERENCES "public"."list"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_toListId_list_id_fk" FOREIGN KEY ("toListId") REFERENCES "public"."list"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_labelId_label_id_fk" FOREIGN KEY ("labelId") REFERENCES "public"."label"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_workspaceMemberId_workspace_members_id_fk" FOREIGN KEY ("workspaceMemberId") REFERENCES "public"."workspace_members"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_activity" ADD CONSTRAINT "card_activity_commentId_card_comments_id_fk" FOREIGN KEY ("commentId") REFERENCES "public"."card_comments"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "_card_workspace_members" ADD CONSTRAINT "_card_workspace_members_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "_card_workspace_members" ADD CONSTRAINT "_card_workspace_members_workspaceMemberId_workspace_members_id_fk" FOREIGN KEY ("workspaceMemberId") REFERENCES "public"."workspace_members"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card" ADD CONSTRAINT "card_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card" ADD CONSTRAINT "card_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card" ADD CONSTRAINT "card_listId_list_id_fk" FOREIGN KEY ("listId") REFERENCES "public"."list"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card" ADD CONSTRAINT "card_importId_import_id_fk" FOREIGN KEY ("importId") REFERENCES "public"."import"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "_card_labels" ADD CONSTRAINT "_card_labels_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "_card_labels" ADD CONSTRAINT "_card_labels_labelId_label_id_fk" FOREIGN KEY ("labelId") REFERENCES "public"."label"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_comments" ADD CONSTRAINT "card_comments_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_comments" ADD CONSTRAINT "card_comments_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_comments" ADD CONSTRAINT "card_comments_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_attachments" ADD CONSTRAINT "card_attachments_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "card_attachments" ADD CONSTRAINT "card_attachments_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "feedback" ADD CONSTRAINT "feedback_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "import" ADD CONSTRAINT "import_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "label" ADD CONSTRAINT "label_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "label" ADD CONSTRAINT "label_boardId_board_id_fk" FOREIGN KEY ("boardId") REFERENCES "public"."board"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "label" ADD CONSTRAINT "label_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "label" ADD CONSTRAINT "label_importId_import_id_fk" FOREIGN KEY ("importId") REFERENCES "public"."import"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "list" ADD CONSTRAINT "list_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "list" ADD CONSTRAINT "list_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "list" ADD CONSTRAINT "list_boardId_board_id_fk" FOREIGN KEY ("boardId") REFERENCES "public"."board"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "list" ADD CONSTRAINT "list_importId_import_id_fk" FOREIGN KEY ("importId") REFERENCES "public"."import"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "user_board_favorites" ADD CONSTRAINT "user_board_favorites_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "user_board_favorites" ADD CONSTRAINT "user_board_favorites_boardId_board_id_fk" FOREIGN KEY ("boardId") REFERENCES "public"."board"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_cardId_card_id_fk" FOREIGN KEY ("cardId") REFERENCES "public"."card"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_boardId_board_id_fk" FOREIGN KEY ("boardId") REFERENCES "public"."board"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "integrations" ADD CONSTRAINT "integrations_workspaceId_workspace_id_fk" FOREIGN KEY ("workspaceId") REFERENCES "public"."workspace"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "integrations" ADD CONSTRAINT "integrations_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace_webhooks" ADD CONSTRAINT "workspace_webhooks_workspaceId_workspace_id_fk" FOREIGN KEY ("workspaceId") REFERENCES "public"."workspace"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace_webhooks" ADD CONSTRAINT "workspace_webhooks_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace_members" ADD CONSTRAINT "workspace_members_userId_user_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace_members" ADD CONSTRAINT "workspace_members_workspaceId_workspace_id_fk" FOREIGN KEY ("workspaceId") REFERENCES "public"."workspace"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace_members" ADD CONSTRAINT "workspace_members_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace" ADD CONSTRAINT "workspace_createdBy_user_id_fk" FOREIGN KEY ("createdBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
 ALTER TABLE "workspace" ADD CONSTRAINT "workspace_deletedBy_user_id_fk" FOREIGN KEY ("deletedBy") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Create Indexes
CREATE INDEX IF NOT EXISTS "board_visibility_idx" ON "board" USING btree ("visibility");
CREATE INDEX IF NOT EXISTS "board_workspaceId_idx" ON "board" USING btree ("workspaceId");
CREATE INDEX IF NOT EXISTS "card_listId_idx" ON "card" USING btree ("listId");
CREATE INDEX IF NOT EXISTS "card_createdAt_idx" ON "card" USING btree ("createdAt");
CREATE INDEX IF NOT EXISTS "list_boardId_idx" ON "list" USING btree ("boardId");
CREATE INDEX IF NOT EXISTS "workspace_members_workspaceId_idx" ON "workspace_members" USING btree ("workspaceId");
CREATE INDEX IF NOT EXISTS "workspace_members_userId_idx" ON "workspace_members" USING btree ("userId");
CREATE INDEX IF NOT EXISTS "workspace_slug_idx" ON "workspace" USING btree ("slug");

-- Full-text search support
ALTER TABLE "card" ADD COLUMN IF NOT EXISTS "searchText" tsvector;

CREATE INDEX IF NOT EXISTS "card_search_idx" ON "card" USING gin ("searchText");

-- Setup complete!
-- Next steps:
-- 1. Add environment variables to Vercel:
--    - NEXT_PUBLIC_BASE_URL=https://your-domain.vercel.app
--    - BETTER_AUTH_SECRET=generate-a-32-char-secret
--    - POSTGRES_URL=your-supabase-connection-string
--
-- 2. Deploy the app to Vercel
-- 3. Create your first workspace and invite team members
