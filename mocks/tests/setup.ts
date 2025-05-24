import { setupServer } from "msw/node";
import {
  handlers,
  db,
  type User,
  type Post,
  type Tag,
  type Comment,
} from "../mocks";
import { beforeAll, beforeEach, afterEach, afterAll } from "vitest";

// Create MSW server with our handlers
export const server = setupServer(...handlers());

// Helper function to get the hash password format that the mock uses
const mockHashPassword = (password: string): string => {
  return `hashed_${password}_${Date.now().toString(36)}`;
};

// Reset and seed database with test data
export function resetAndSeedDatabase() {
  // Clear all existing data
  db.user.deleteMany({ where: {} });
  db.post.deleteMany({ where: {} });
  db.comment.deleteMany({ where: {} });
  db.tag.deleteMany({ where: {} });
  db.like.deleteMany({ where: {} });
  db.follow.deleteMany({ where: {} });
  db.refreshToken.deleteMany({ where: {} });

  // Create test users with known credentials
  const testUser = db.user.create({
    id: "user-1",
    username: "testuser",
    email: "test@example.com",
    firstName: "Test",
    lastName: "User",
    password: "test123", // Store plain text for our tests
    isActive: true,
    role: "user",
  });

  const adminUser = db.user.create({
    id: "admin-1",
    username: "admin",
    email: "admin@example.com",
    firstName: "Admin",
    lastName: "User",
    password: "admin123", // Store plain text for our tests
    isActive: true,
    role: "admin",
  });

  const inactiveUser = db.user.create({
    id: "inactive-1",
    username: "inactive",
    email: "inactive@example.com",
    firstName: "Inactive",
    lastName: "User",
    password: "inactive123", // Store plain text for our tests
    isActive: false,
    role: "user",
  });

  // Create test tags
  const javascriptTag = db.tag.create({
    id: "tag-1",
    name: "JavaScript",
    slug: "javascript",
    color: "#f7df1e",
    description: "JavaScript programming language",
  });

  const reactTag = db.tag.create({
    id: "tag-2",
    name: "React",
    slug: "react",
    color: "#61dafb",
    description: "React JavaScript library",
  });

  const nodeTag = db.tag.create({
    id: "tag-3",
    name: "Node.js",
    slug: "nodejs",
    color: "#339933",
    description: "Node.js runtime",
  });

  // Create test posts
  const testPost = db.post.create({
    id: "post-1",
    title: "Test Post by User",
    slug: "test-post-by-user",
    content: "This is a test post content created by the test user.",
    excerpt: "This is a test post excerpt...",
    status: "published",
    viewCount: 5,
    author: testUser,
    tags: [javascriptTag, reactTag],
  });

  const adminPost = db.post.create({
    id: "admin-post",
    title: "Admin Post",
    slug: "admin-post",
    content: "This is an admin post content.",
    excerpt: "This is an admin post excerpt...",
    status: "published",
    viewCount: 10,
    author: adminUser,
    tags: [javascriptTag, nodeTag],
  });

  const draftPost = db.post.create({
    id: "post-3",
    title: "Draft Post",
    slug: "draft-post",
    content: "This is a draft post content.",
    excerpt: "This is a draft post excerpt...",
    status: "draft",
    viewCount: 0,
    author: testUser,
    tags: [reactTag],
  });

  // Create test comments
  const testComment = db.comment.create({
    id: "comment-1",
    content: "This is a test comment",
    author: testUser,
    post: testPost,
    parentComment: undefined,
    isDeleted: false,
  });

  const adminComment = db.comment.create({
    id: "comment-2",
    content: "This is an admin comment",
    author: adminUser,
    post: testPost,
    parentComment: undefined,
    isDeleted: false,
  });

  const replyComment = db.comment.create({
    id: "comment-3",
    content: "This is a reply to the test comment",
    author: adminUser,
    post: testPost,
    parentComment: testComment,
    isDeleted: false,
  });

  // Create test likes
  db.like.create({
    id: "like-1",
    user: adminUser,
    targetType: "post",
    targetId: testPost.id,
  });

  db.like.create({
    id: "like-2",
    user: testUser,
    targetType: "comment",
    targetId: testComment.id,
  });
}

// Helper functions to get test data
export function getTestUser(username?: string): User | null {
  if (username) {
    return db.user.findFirst({ where: { username: { equals: username } } });
  }
  return db.user.findFirst({ where: { username: { equals: "testuser" } } });
}

export function getAdminUser(): User | null {
  return db.user.findFirst({ where: { username: { equals: "admin" } } });
}

export function getInactiveUser(): User | null {
  return db.user.findFirst({ where: { username: { equals: "inactive" } } });
}

export function getTestPost(id?: string): Post | null {
  if (id) {
    return db.post.findFirst({ where: { id: { equals: id } } });
  }
  return db.post.findFirst({ where: { id: { equals: "post-1" } } });
}

export function getTestTag(name?: string): Tag | null {
  if (name) {
    return db.tag.findFirst({ where: { name: { equals: name } } });
  }
  return db.tag.findFirst({ where: { name: { equals: "JavaScript" } } });
}

export function getTestComment(id?: string): Comment | null {
  if (id) {
    return db.comment.findFirst({ where: { id: { equals: id } } });
  }
  return db.comment.findFirst({ where: { id: { equals: "comment-1" } } });
}

// MSW Server lifecycle
beforeAll(() => {
  // Start the MSW server before all tests
  server.listen({ onUnhandledRequest: "error" });
});

beforeEach(() => {
  // Reset and reseed database before each test
  resetAndSeedDatabase();
});

afterEach(() => {
  // Reset request handlers after each test
  server.resetHandlers();
});

afterAll(() => {
  // Stop the MSW server after all tests
  server.close();
});
