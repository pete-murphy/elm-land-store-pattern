import { describe, it, expect } from "vitest";
import { getTestUser, getAdminUser } from "./setup";

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

describe("Users API", () => {
  describe("GET /api/me", () => {
    it("should return current authenticated user", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/me`, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.username).toBe("testuser");
      expect(data.email).toBe("test@example.com");
      expect(data).not.toHaveProperty("password"); // Password should not be returned
      expect(data).toHaveProperty("id");
      expect(data).toHaveProperty("firstName");
      expect(data).toHaveProperty("lastName");
    });

    it("should require authentication", async () => {
      const response = await fetch(`${API_BASE}/me`);
      expect(response.status).toBe(401);
    });

    it("should reject invalid token", async () => {
      const response = await fetch(`${API_BASE}/me`, {
        headers: {
          Authorization: "Bearer invalid-token",
        },
      });
      expect(response.status).toBe(401);
    });
  });

  describe("GET /api/users", () => {
    it("should return paginated list of users", async () => {
      const response = await fetch(`${API_BASE}/users`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      expect(data.pagination).toHaveProperty("page", 1);
      expect(data.pagination).toHaveProperty("limit", 10);
      expect(data.pagination).toHaveProperty("totalCount");
      expect(data.pagination).toHaveProperty("totalPages");
    });

    it("should support pagination parameters", async () => {
      const response = await fetch(`${API_BASE}/users?page=1&limit=5`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });

    it("should support search by username", async () => {
      const response = await fetch(`${API_BASE}/users?search=test`);

      expect(response.status).toBe(200);
      const data = await response.json();

      // Should find users with 'test' in their username
      data.data.forEach((user: any) => {
        expect(user.username.toLowerCase()).toContain("test");
      });
    });
  });

  describe("GET /api/users/:id", () => {
    it("should return specific user by ID", async () => {
      const testUser = getTestUser();

      const response = await fetch(`${API_BASE}/users/${testUser?.id}`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.id).toBe(testUser?.id);
      expect(data.username).toBe(testUser?.username);
      expect(data.email).toBe(testUser?.email);
    });

    it("should return 404 for non-existent user", async () => {
      const response = await fetch(`${API_BASE}/users/non-existent-id`);
      expect(response.status).toBe(404);
    });
  });

  describe("GET /api/users/:id/posts", () => {
    it("should return paginated posts by user", async () => {
      const testUser = getTestUser();

      const response = await fetch(`${API_BASE}/users/${testUser?.id}/posts`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      // All posts should belong to the specified user
      data.data.forEach((post: any) => {
        expect(post.author.id).toBe(testUser?.id);
      });
    });

    it("should support status filter", async () => {
      const testUser = getTestUser();

      const response = await fetch(
        `${API_BASE}/users/${testUser?.id}/posts?status=published`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      data.data.forEach((post: any) => {
        expect(post.status).toBe("published");
      });
    });

    it("should support pagination", async () => {
      const testUser = getTestUser();

      const response = await fetch(
        `${API_BASE}/users/${testUser?.id}/posts?page=1&limit=5`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });
  });

  describe("GET /api/users/:id/comments", () => {
    it("should return paginated comments by user", async () => {
      const testUser = getTestUser();

      const response = await fetch(
        `${API_BASE}/users/${testUser?.id}/comments`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      // All comments should belong to the specified user and not be deleted
      data.data.forEach((comment: any) => {
        expect(comment.author.id).toBe(testUser?.id);
        expect(comment.isDeleted).toBe(false);
      });
    });

    it("should support pagination", async () => {
      const testUser = getTestUser();

      const response = await fetch(
        `${API_BASE}/users/${testUser?.id}/comments?page=1&limit=5`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });
  });

  describe("POST /api/users/:id/follow", () => {
    it("should allow user to follow another user", async () => {
      const accessToken = await getAccessToken();
      const adminUser = getAdminUser();

      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      expect(response.status).toBe(201);
      const data = await response.json();

      expect(data.follower.username).toBe("testuser");
      expect(data.following.id).toBe(adminUser?.id);
    });

    it("should prevent user from following themselves", async () => {
      const accessToken = await getAccessToken();
      const testUser = getTestUser();

      const response = await fetch(`${API_BASE}/users/${testUser?.id}/follow`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      expect(response.status).toBe(400);
    });

    it("should prevent duplicate follows", async () => {
      const accessToken = await getAccessToken();
      const adminUser = getAdminUser();

      // First follow
      await fetch(`${API_BASE}/users/${adminUser?.id}/follow`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      // Try to follow again
      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      expect(response.status).toBe(409);
      const data = await response.json();
      expect(data.message).toBe("Already following");
    });

    it("should return 404 for non-existent user", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/users/non-existent-id/follow`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      expect(response.status).toBe(404);
    });

    it("should require authentication", async () => {
      const adminUser = getAdminUser();

      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "POST",
        }
      );

      expect(response.status).toBe(401);
    });
  });

  describe("DELETE /api/users/:id/follow", () => {
    it("should allow user to unfollow another user", async () => {
      const accessToken = await getAccessToken();
      const adminUser = getAdminUser();

      // First follow the user
      await fetch(`${API_BASE}/users/${adminUser?.id}/follow`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      // Then unfollow
      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      expect(response.status).toBe(204);
    });

    it("should return 404 if not following the user", async () => {
      const accessToken = await getAccessToken();
      const adminUser = getAdminUser();

      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      expect(response.status).toBe(404);
    });

    it("should require authentication", async () => {
      const adminUser = getAdminUser();

      const response = await fetch(
        `${API_BASE}/users/${adminUser?.id}/follow`,
        {
          method: "DELETE",
        }
      );

      expect(response.status).toBe(401);
    });
  });
});

describe("Tags API", () => {
  describe("GET /api/tags", () => {
    it("should return all tags", async () => {
      const response = await fetch(`${API_BASE}/tags`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(Array.isArray(data)).toBe(true);

      // Check that tags have the expected structure
      data.forEach((tag: any) => {
        expect(tag).toHaveProperty("id");
        expect(tag).toHaveProperty("name");
        expect(tag).toHaveProperty("slug");
        expect(tag).toHaveProperty("color");
        expect(tag).toHaveProperty("createdAt");
      });
    });

    it("should support search by tag name", async () => {
      const response = await fetch(`${API_BASE}/tags?search=Java`);

      expect(response.status).toBe(200);
      const data = await response.json();

      // Should find tags with 'Java' in their name
      data.forEach((tag: any) => {
        expect(tag.name.toLowerCase()).toContain("java");
      });
    });
  });

  describe("GET /api/tags/:slug/posts", () => {
    it("should return paginated posts for a tag", async () => {
      const response = await fetch(`${API_BASE}/tags/javascript/posts`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      // All posts should be published and have the tag
      data.data.forEach((post: any) => {
        expect(post.status).toBe("published");
        const hasTag =
          post.tags && post.tags.some((tag: any) => tag.slug === "javascript");
        expect(hasTag).toBe(true);
      });
    });

    it("should support pagination", async () => {
      const response = await fetch(
        `${API_BASE}/tags/javascript/posts?page=1&limit=5`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });

    it("should return empty results for non-existent tag", async () => {
      const response = await fetch(`${API_BASE}/tags/non-existent-tag/posts`);

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.data).toHaveLength(0);
      expect(data.pagination.totalCount).toBe(0);
    });
  });
});
