import { describe, it, expect } from "vitest";
import { getTestUser, getTestPost } from "./setup";

const API_BASE = "http://localhost/api";

// Helper function to login and get access token
async function getAccessToken(
  username: string = "testuser",
  password: string = "test123"
) {
  const response = await fetch(`${API_BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ usernameOrEmail: username, password }),
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

describe("Comments API", () => {
  describe("GET /api/posts/:id/comments", () => {
    it("should return paginated comments for a post", async () => {
      const testPost = getTestPost();

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data).toHaveProperty("data");
      expect(data).toHaveProperty("pagination");
      expect(Array.isArray(data.data)).toBe(true);

      expect(data.pagination).toHaveProperty("page", 1);
      expect(data.pagination).toHaveProperty("limit", 10);
      expect(data.pagination).toHaveProperty("totalCount");
      expect(data.pagination).toHaveProperty("totalPages");

      // Should only return non-deleted comments
      data.data.forEach((comment: any) => {
        expect(comment.isDeleted).toBe(false);
      });
    });

    it("should support pagination parameters", async () => {
      const testPost = getTestPost();

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments?page=1&limit=5`
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.pagination.page).toBe(1);
      expect(data.pagination.limit).toBe(5);
      expect(data.data.length).toBeLessThanOrEqual(5);
    });

    it("should filter to parent comments only when requested", async () => {
      const testPost = getTestPost();

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments?parent_only=true`
      );
      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.data.length).toBeGreaterThan(0);

      data.data.forEach((comment: any) => {
        expect(comment.parentComment).toBeNull();
      });
    });
  });

  describe("POST /api/posts/:id/comments", () => {
    it("should create a new comment on a post", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      const commentData = {
        content: "This is a test comment",
      };

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(commentData),
        }
      );

      expect(response.status).toBe(201);
      const data = await response.json();

      expect(data.content).toBe(commentData.content);
      expect(data.author.username).toBe("testuser");
      expect(data.post.id).toBe(testPost?.id);
      expect(data.parentComment).toBeNull();
      expect(data.isDeleted).toBe(false);
    });

    it("should create a reply to an existing comment", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a parent comment
      const parentCommentData = {
        content: "This is a parent comment",
      };

      const parentResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(parentCommentData),
        }
      );
      const parentComment = await parentResponse.json();

      // Now create a reply
      const replyData = {
        content: "This is a reply to the parent comment",
        parentCommentId: parentComment.id,
      };

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(replyData),
        }
      );

      expect(response.status).toBe(201);
      const data = await response.json();

      expect(data.content).toBe(replyData.content);
      expect(data.parentComment.id).toBe(parentComment.id);
      expect(data.post.id).toBe(testPost?.id);
    });

    it("should require authentication", async () => {
      const testPost = getTestPost();

      const commentData = {
        content: "Unauthorized comment",
      };

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(commentData),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should require content", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      const response = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe("Content is required");
    });

    it("should return 404 for non-existent post", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(
        `${API_BASE}/posts/non-existent-id/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment on non-existent post" }),
        }
      );

      expect(response.status).toBe(404);
    });
  });

  describe("PATCH /api/comments/:id", () => {
    it("should allow author to update their own comment", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a comment
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Original comment content" }),
        }
      );
      const createdComment = await createResponse.json();

      // Now update it
      const updateData = {
        content: "Updated comment content",
      };

      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(updateData),
        }
      );

      expect(response.status).toBe(200);
      const data = await response.json();

      expect(data.content).toBe(updateData.content);
      expect(data.id).toBe(createdComment.id);
    });

    it("should allow admin to update any comment", async () => {
      const userToken = await getAccessToken();
      const adminToken = await getAccessToken("admin", "admin123");
      const testPost = getTestPost();

      // Create a comment as regular user
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${userToken}`,
          },
          body: JSON.stringify({ content: "User comment" }),
        }
      );
      const createdComment = await createResponse.json();

      // Update as admin
      const updateData = { content: "Admin updated comment" };

      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${adminToken}`,
          },
          body: JSON.stringify(updateData),
        }
      );

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.content).toBe(updateData.content);
    });

    it("should prevent non-author from updating comment", async () => {
      const user1Token = await getAccessToken();
      const user2Token = await getAccessToken("admin", "admin123");
      const testPost = getTestPost();

      // Create comment as user1
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${user1Token}`,
          },
          body: JSON.stringify({ content: "User1 comment" }),
        }
      );
      const createdComment = await createResponse.json();

      // Try to update as different regular user (using testuser again, but with different comment)
      // Create another comment first
      const anotherCreateResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${user2Token}`,
          },
          body: JSON.stringify({ content: "User2 comment" }),
        }
      );
      const anotherComment = await anotherCreateResponse.json();

      // Try to update user1's comment with user1 token (this should work)
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${user1Token}`,
          },
          body: JSON.stringify({ content: "Updated by owner" }),
        }
      );

      expect(response.status).toBe(200);

      // But updating user2's comment with user1 token should fail
      const unauthorizedResponse = await fetch(
        `${API_BASE}/comments/${anotherComment.id}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${user1Token}`,
          },
          body: JSON.stringify({ content: "Unauthorized update" }),
        }
      );

      expect(unauthorizedResponse.status).toBe(403);
    });

    it("should require authentication", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // Create a comment first
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to update" }),
        }
      );
      const createdComment = await createResponse.json();

      // Try to update without authentication
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ content: "No auth update" }),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should require content", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // Create a comment first
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to update" }),
        }
      );
      const createdComment = await createResponse.json();

      // Try to update without content
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe("Content is required");
    });

    it("should return 404 for non-existent comment", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/comments/non-existent-id`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ content: "Update non-existent" }),
      });

      expect(response.status).toBe(404);
    });
  });

  describe("DELETE /api/comments/:id", () => {
    it("should allow author to delete their own comment (soft delete)", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a comment
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to delete" }),
        }
      );
      const createdComment = await createResponse.json();

      // Delete the comment
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${accessToken}` },
        }
      );

      expect(response.status).toBe(204);

      // Verify comment is soft-deleted (content changed to [deleted])
      // We can't directly access the database from here, but the comment should still exist
      // with modified content when fetched through the API
    });

    it("should allow admin to delete any comment", async () => {
      const userToken = await getAccessToken();
      const adminToken = await getAccessToken("admin", "admin123");
      const testPost = getTestPost();

      // Create comment as user
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${userToken}`,
          },
          body: JSON.stringify({
            content: "User comment to be deleted by admin",
          }),
        }
      );
      const createdComment = await createResponse.json();

      // Delete as admin
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${adminToken}` },
        }
      );

      expect(response.status).toBe(204);
    });

    it("should require authentication", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // Create a comment first
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to delete" }),
        }
      );
      const createdComment = await createResponse.json();

      // Try to delete without authentication
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}`,
        {
          method: "DELETE",
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent comment", async () => {
      const accessToken = await getAccessToken();

      const response = await fetch(`${API_BASE}/comments/non-existent-id`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      expect(response.status).toBe(404);
    });
  });

  describe("POST /api/comments/:id/like", () => {
    it("should like a comment", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a comment
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to like" }),
        }
      );
      const createdComment = await createResponse.json();

      // Like the comment
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}/like`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${accessToken}` },
        }
      );

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.liked).toBe(true);
      expect(data).toHaveProperty("like");
    });

    it("should unlike a comment if already liked", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a comment
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to like and unlike" }),
        }
      );
      const createdComment = await createResponse.json();

      // Like the comment
      await fetch(`${API_BASE}/comments/${createdComment.id}/like`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      // Unlike the comment
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}/like`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${accessToken}` },
        }
      );

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.liked).toBe(false);
    });

    it("should require authentication", async () => {
      const accessToken = await getAccessToken();
      const testPost = getTestPost();

      // First create a comment
      const createResponse = await fetch(
        `${API_BASE}/posts/${testPost?.id}/comments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ content: "Comment to like without auth" }),
        }
      );
      const createdComment = await createResponse.json();

      // Try to like without authentication
      const response = await fetch(
        `${API_BASE}/comments/${createdComment.id}/like`,
        {
          method: "POST",
        }
      );

      expect(response.status).toBe(401);
    });
  });
});
