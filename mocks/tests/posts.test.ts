import { describe, it, expect } from "vitest";
import { getTestUser, getAdminUser, getTestPost, getTestTag } from "./setup";

const API_BASE = "http://localhost/api";

// Helper function to login and get access token
async function getAccessToken(
  username: string = "testuser",
  password: string = "test123"
) {
  // Determine if the input is an email or username
  const isEmail = username.includes("@");
  const loginData = isEmail
    ? { email: username, password }
    : { username, password };

  const response = await fetch(`${API_BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(loginData),
  });
  let data = {};
  try {
    data = await response.json();
  } catch (e) {
    const text = await response.text();
    return undefined;
  }
  if (!data || typeof data !== "object" || !("accessToken" in data)) {
    return undefined;
  }
  return (data as any).accessToken;
}

describe("Posts API", () => {
  describe("GET /api/posts", () => {
    it("should return paginated published posts by default", async () => {
      const response = await fetch(`${API_BASE}/posts`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      expect(data.pagination).toHaveProperty("page", 1);
      expect(data.pagination).toHaveProperty("limit", 10);
      expect(data.pagination).toHaveProperty("totalCount");
      expect(data.pagination).toHaveProperty("totalPages");

      // Should only return published posts by default
      data.data.forEach((post: any) => {
        expect(post.status).toBe("published");
      });
    });

    it("should support pagination parameters", async () => {
      const response = await fetch(`${API_BASE}/posts?page=1&limit=5`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });

    it("should filter by tag", async () => {
      const response = await fetch(`${API_BASE}/posts?tag=JavaScript`);

      expect(response.status).toBe(200);
      const data = await response.json();

      // All posts should include the specified tag
      data.data.forEach((post: any) => {
        const hasTag =
          post.tags && post.tags.some((tag: any) => tag.name === "JavaScript");
        expect(hasTag).toBe(true);
      });
    });

    it("should filter by author username", async () => {
      const response = await fetch(`${API_BASE}/posts?author=testuser`);

      expect(response.status).toBe(200);
      const data = await response.json();

      data.data.forEach((post: any) => {
        expect(post.author.username).toBe("testuser");
      });
    });

    it("should filter by status", async () => {
      const response = await fetch(`${API_BASE}/posts?status=draft`);

      expect(response.status).toBe(200);
      const data = await response.json();

      data.data.forEach((post: any) => {
        expect(post.status).toBe("draft");
      });
    });

    it("should search by title", async () => {
      const response = await fetch(`${API_BASE}/posts?search=Test`);

      expect(response.status).toBe(200);
      const data = await response.json();

      data.data.forEach((post: any) => {
        expect(post.title.toLowerCase()).toContain("test");
      });
    });

    it("should support sorting", async () => {
      const response = await fetch(`${API_BASE}/posts?sort=title&order=asc`);

      expect(response.status).toBe(200);
      const data = await response.json();

      // Check if posts are sorted by title in ascending order
      if (data.data.length > 1) {
        for (let i = 1; i < data.data.length; i++) {
          expect(data.data[i].title >= data.data[i - 1].title).toBe(true);
        }
      }
    });
  });

  describe("GET /api/posts/:id", () => {
    it("should return a specific post and increment view count", async () => {
      const testPost = getTestPost();
      const initialViewCount = testPost?.viewCount || 0;

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.id).toBe(testPost?.id);
      expect(data.title).toBe(testPost?.title);
      expect(data.viewCount).toBe(initialViewCount + 1);
    });

    it("should return 404 for non-existent post", async () => {
      const response = await fetch(`${API_BASE}/posts/non-existent-id`);
      expect(response.status).toBe(404);
    });
  });

  describe("GET /api/posts/slug/:slug", () => {
    it("should return a specific post by slug and increment view count", async () => {
      const testPost = getTestPost();
      const initialViewCount = testPost?.viewCount || 0;

      const response = await fetch(`${API_BASE}/posts/slug/${testPost?.slug}`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.id).toBe(testPost?.id);
      expect(data.title).toBe(testPost?.title);
      expect(data.slug).toBe(testPost?.slug);
      expect(data.viewCount).toBe(initialViewCount + 1);
    });

    it("should return 404 for non-existent slug", async () => {
      const response = await fetch(`${API_BASE}/posts/slug/non-existent-slug`);
      expect(response.status).toBe(404);
    });

    it("should return the same post data when accessed by slug vs ID", async () => {
      const testPost = getTestPost();

      // Get post by ID
      const idResponse = await fetch(`${API_BASE}/posts/${testPost?.id}`);
      const postById = await idResponse.json();

      // Get post by slug
      const slugResponse = await fetch(
        `${API_BASE}/posts/slug/${testPost?.slug}`
      );
      const postBySlug = await slugResponse.json();

      expect(slugResponse.status).toBe(200);
      expect(postBySlug.id).toBe(postById.id);
      expect(postBySlug.title).toBe(postById.title);
      expect(postBySlug.content).toBe(postById.content);
      expect(postBySlug.slug).toBe(postById.slug);
      // View counts will differ by 2 since we fetched twice
      expect(postBySlug.viewCount).toBe(postById.viewCount + 1);
    });
  });

  describe("POST /api/posts", () => {
    it("should create a new post with authentication", async () => {
      const accessToken = await getAccessToken();
      const testTag = getTestTag();

      const postData = {
        title: "New Test Post",
        content: "This is the content of the new test post",
        excerpt: "This is a test excerpt",
        status: "published",
        tagIds: [testTag?.id],
      };

      const response = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(postData),
      });

      expect(response.status).toBe(201);
      const data = await response.json();

      expect(data.title).toBe(postData.title);
      expect(data.content).toBe(postData.content);
      expect(data.status).toBe(postData.status);
      expect(data.slug).toBe("new-test-post");
      expect(data.viewCount).toBe(0);
      expect(data.author.username).toBe("testuser");
      expect(data.tags).toHaveLength(1);
    });

    it("should create post with default status as draft", async () => {
      const accessToken = await getAccessToken();

      const postData = {
        title: "Draft Post",
        content: "This is a draft post",
      };

      const response = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(postData),
      });

      expect(response.status).toBe(201);
      const data = await response.json();
      expect(data.status).toBe("draft");
    });

    it("should auto-generate excerpt if not provided", async () => {
      const accessToken = await getAccessToken();

      const longContent = "A".repeat(300);
      const postData = {
        title: "Post Without Excerpt",
        content: longContent,
      };

      const response = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(postData),
      });

      expect(response.status).toBe(201);
      const data = await response.json();
      expect(data.excerpt).toBe(longContent.substring(0, 200) + "...");
    });

    it("should require authentication", async () => {
      const postData = {
        title: "Unauthorized Post",
        content: "This should fail",
      };

      const response = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(postData),
      });

      expect(response.status).toBe(401);
    });

    it("should require title and content", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ title: "Only Title" }),
      });

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe("Title and content are required");
    });
  });

  describe("PATCH /api/posts/:id", () => {
    it("should allow author to update their own post", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      const updateData = {
        title: "Updated Title",
        content: "Updated content",
        status: "published",
      };

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(updateData),
      });

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.title).toBe(updateData.title);
      expect(data.content).toBe(updateData.content);
      expect(data.status).toBe(updateData.status);
      expect(data.slug).toBe("updated-title");
    });

    it("should allow admin to update any post", async () => {
      const adminToken = await getAccessToken("admin", "admin123");
      const testPost = getTestPost();

      const updateData = { title: "Admin Updated Title" };

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${adminToken}`,
        },
        body: JSON.stringify(updateData),
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.title).toBe(updateData.title);
    });

    it("should prevent non-author from updating post", async () => {
      // First create a post with one user
      const userToken = await getAccessToken();
      const createResponse = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${userToken}`,
        },
        body: JSON.stringify({
          title: "User Post",
          content: "User content",
        }),
      });
      const createdPost = await createResponse.json();

      // Try to update with admin post (different author)
      const adminPost = getTestPost("admin-post");
      const updateData = { title: "Unauthorized Update" };

      const response = await fetch(`${API_BASE}/posts/${adminPost?.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${userToken}`,
        },
        body: JSON.stringify(updateData),
      });

      expect(response.status).toBe(403);
    });

    it("should require authentication", async () => {
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "No Auth Update" }),
      });

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent post", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/posts/non-existent-id`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ title: "Update Non-existent" }),
      });

      expect(response.status).toBe(404);
    });
  });

  describe("DELETE /api/posts/:id", () => {
    it("should allow author to delete their own post", async () => {
      const accessToken = await getAccessToken();

      // First create a post
      const createResponse = await fetch(`${API_BASE}/posts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          title: "Post to Delete",
          content: "This post will be deleted",
        }),
      });
      const createdPost = await createResponse.json();

      // Delete the post
      const response = await fetch(`${API_BASE}/posts/${createdPost.id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      expect(response.status).toBe(204);

      // Verify post is deleted
      const getResponse = await fetch(`${API_BASE}/posts/${createdPost.id}`);
      expect(getResponse.status).toBe(404);
    });

    it("should allow admin to delete any post", async () => {
      const adminToken = await getAccessToken("admin", "admin123");
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${adminToken}` },
      });

      expect(response.status).toBe(204);
    });

    it("should require authentication", async () => {
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}`, {
        method: "DELETE",
      });

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent post", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/posts/non-existent-id`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      expect(response.status).toBe(404);
    });
  });

  describe("POST /api/posts/:id/like", () => {
    it("should like a post", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}/like`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.liked).toBe(true);
      expect(data).toHaveProperty("like");
    });

    it("should unlike a post if already liked", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First like
      await fetch(`${API_BASE}/posts/${testPost?.id}/like`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      // Then unlike
      const response = await fetch(`${API_BASE}/posts/${testPost?.id}/like`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.liked).toBe(false);
    });

    it("should require authentication", async () => {
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}/like`, {
        method: "POST",
      });

      expect(response.status).toBe(401);
    });
  });

  describe("GET /api/posts/:id/stats", () => {
    it("should return post statistics", async () => {
      const testPost = getTestPost();

      const response = await fetch(`${API_BASE}/posts/${testPost?.id}/stats`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("views");
      expect(data).toHaveProperty("likes");
      expect(data).toHaveProperty("comments");
      expect(typeof data.views).toBe("number");
      expect(typeof data.likes).toBe("number");
      expect(typeof data.comments).toBe("number");
    });

    it("should return 404 for non-existent post", async () => {
      const response = await fetch(`${API_BASE}/posts/non-existent-id/stats`);
      expect(response.status).toBe(404);
    });
  });
});
