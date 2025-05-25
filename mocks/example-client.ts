// Example setup for using the mock API
import { setupWorker } from "msw/browser";
import { handlers, db } from "./mocks";

// Setup MSW worker for browser
export const worker = setupWorker(...(handlers() as any));

// Example usage and helper functions
export class MockApiClient {
  private baseUrl = "/api";
  private accessToken: string | null = null;
  private refreshToken: string | null = null;

  constructor() {
    // Try to restore tokens from localStorage
    this.accessToken = localStorage.getItem("access_token");
    this.refreshToken = localStorage.getItem("refresh_token");
  }

  // Set tokens
  setTokens(accessToken: string, refreshToken?: string) {
    this.accessToken = accessToken;
    if (refreshToken) {
      this.refreshToken = refreshToken;
    }

    // Store in localStorage
    localStorage.setItem("access_token", accessToken);
    if (refreshToken) {
      localStorage.setItem("refresh_token", refreshToken);
    }
  }

  // Clear tokens
  clearTokens() {
    this.accessToken = null;
    this.refreshToken = null;
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
  }

  // Get auth headers
  private getAuthHeaders() {
    return {
      "Content-Type": "application/json",
      ...(this.accessToken && {
        Authorization: `Bearer ${this.accessToken}`,
      }),
    };
  }

  // Helper method for API calls with automatic token refresh
  private async request(endpoint: string, options: RequestInit = {}) {
    const makeRequest = async (token?: string) => {
      const headers = {
        "Content-Type": "application/json",
        ...options.headers,
        ...(token && { Authorization: `Bearer ${token}` }),
      };

      return fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers,
      });
    };

    let response = await makeRequest(this.accessToken || undefined);

    // If token is expired and we have a refresh token, try to refresh
    if (response.status === 401 && this.refreshToken) {
      try {
        const refreshResult = await this.refreshAccessToken();
        if (refreshResult.accessToken) {
          // Retry the original request with the new token
          response = await makeRequest(refreshResult.accessToken);
        }
      } catch (error) {
        // Refresh failed, clear tokens
        this.clearTokens();
        throw new Error("Authentication failed. Please login again.");
      }
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.error ||
          `API Error: ${response.status} ${response.statusText}`
      );
    }

    return response.status === 204 ? null : response.json();
  }

  // === AUTHENTICATION METHODS ===

  async login(credentials: {
    username?: string;
    email?: string;
    password: string;
  }) {
    const response = await fetch(`${this.baseUrl}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(credentials),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || "Login failed");
    }

    const data = await response.json();
    this.setTokens(data.accessToken, data.refreshToken);
    return data;
  }

  async logout() {
    try {
      if (this.refreshToken) {
        await fetch(`${this.baseUrl}/auth/logout`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken: this.refreshToken }),
        });
      }
    } finally {
      this.clearTokens();
    }
  }

  async logoutAll() {
    const result = await this.request("/auth/logout-all", { method: "POST" });
    this.clearTokens();
    return result;
  }

  async refreshAccessToken() {
    if (!this.refreshToken) {
      throw new Error("No refresh token available");
    }

    const response = await fetch(`${this.baseUrl}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: this.refreshToken }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      this.clearTokens();
      throw new Error(errorData.error || "Token refresh failed");
    }

    const data = await response.json();
    this.setTokens(data.accessToken);
    return data;
  }

  async verifyToken() {
    return this.request("/auth/verify");
  }

  // Check if user is authenticated
  isAuthenticated(): boolean {
    return !!this.accessToken;
  }

  // === USER METHODS ===
  async getCurrentUser() {
    return this.request("/me");
  }

  async getUsers(
    params: { page?: number; limit?: number; search?: string } = {}
  ) {
    const searchParams = new URLSearchParams();
    if (params.page) searchParams.set("page", params.page.toString());
    if (params.limit) searchParams.set("limit", params.limit.toString());
    if (params.search) searchParams.set("search", params.search);

    return this.request(`/users?${searchParams}`);
  }

  async getUser(userId: string) {
    return this.request(`/users/${userId}`);
  }

  async followUser(userId: string) {
    return this.request(`/users/${userId}/follow`, { method: "POST" });
  }

  async unfollowUser(userId: string) {
    return this.request(`/users/${userId}/follow`, { method: "DELETE" });
  }

  // === POST METHODS ===
  async getPosts(
    params: {
      page?: number;
      limit?: number;
      tag?: string;
      author?: string;
      status?: string;
      search?: string;
      sort?: string;
      order?: "asc" | "desc";
    } = {}
  ) {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        searchParams.set(key, value.toString());
      }
    });

    return this.request(`/posts?${searchParams}`);
  }

  async getPost(postId: string) {
    return this.request(`/posts/${postId}`);
  }

  async createPost(post: {
    title: string;
    content: string;
    excerpt?: string;
    status?: "draft" | "published";
    tagIds?: string[];
  }) {
    return this.request("/posts", {
      method: "POST",
      body: JSON.stringify(post),
    });
  }

  async updatePost(
    postId: string,
    updates: {
      title?: string;
      content?: string;
      excerpt?: string;
      status?: "draft" | "published";
      tagIds?: string[];
    }
  ) {
    return this.request(`/posts/${postId}`, {
      method: "PATCH",
      body: JSON.stringify(updates),
    });
  }

  async deletePost(postId: string) {
    return this.request(`/posts/${postId}`, { method: "DELETE" });
  }

  async likePost(postId: string) {
    return this.request(`/posts/${postId}/like`, { method: "POST" });
  }

  async getPostStats(postId: string) {
    return this.request(`/posts/${postId}/stats`);
  }

  // === COMMENT METHODS ===
  async getPostComments(
    postId: string,
    params: {
      page?: number;
      limit?: number;
      parent_only?: boolean;
    } = {}
  ) {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        searchParams.set(key, value.toString());
      }
    });

    return this.request(`/posts/${postId}/comments?${searchParams}`);
  }

  async createComment(
    postId: string,
    comment: {
      content: string;
      parentCommentId?: string;
    }
  ) {
    return this.request(`/posts/${postId}/comments`, {
      method: "POST",
      body: JSON.stringify(comment),
    });
  }

  async updateComment(commentId: string, content: string) {
    return this.request(`/comments/${commentId}`, {
      method: "PATCH",
      body: JSON.stringify({ content }),
    });
  }

  async deleteComment(commentId: string) {
    return this.request(`/comments/${commentId}`, { method: "DELETE" });
  }

  async likeComment(commentId: string) {
    return this.request(`/comments/${commentId}/like`, { method: "POST" });
  }

  // === TAG METHODS ===
  async getTags(search?: string) {
    const params = search ? `?search=${encodeURIComponent(search)}` : "";
    return this.request(`/tags${params}`);
  }

  async getPostsByTag(
    tagSlug: string,
    params: { page?: number; limit?: number } = {}
  ) {
    const searchParams = new URLSearchParams();
    if (params.page) searchParams.set("page", params.page.toString());
    if (params.limit) searchParams.set("limit", params.limit.toString());

    return this.request(`/tags/${tagSlug}/posts?${searchParams}`);
  }
}

// Initialize the API client
export const apiClient = new MockApiClient();

// Example authentication demo
export async function demonstrateAuthentication() {
  try {
    console.log("🔐 Demonstrating Authentication...");

    // Try logging in with test credentials
    console.log("📝 Logging in with test user...");
    const loginResult = await apiClient.login({
      username: "testuser",
      password: "test123",
    });
    console.log("✅ Login successful:", loginResult.user.username);

    // Get current user
    const currentUser = await apiClient.getCurrentUser();
    console.log("👤 Current user:", currentUser.username);

    // Verify token
    const verification = await apiClient.verifyToken();
    console.log("🔍 Token verification:", verification.valid);

    // Create a post (requires authentication)
    const newPost = await apiClient.createPost({
      title: "My Authenticated Post",
      content: "This post was created using JWT authentication!",
      status: "published",
    });
    console.log("📝 Created post:", newPost.title);

    // Logout
    await apiClient.logout();
    console.log("👋 Logged out successfully");

    console.log("✅ Authentication demonstration complete!");
  } catch (error) {
    console.error("❌ Authentication Error:", error);
  }
}

// Example usage function
export async function demonstrateAPI() {
  try {
    console.log("🚀 Demonstrating Mock API...");

    // Get all users to see available test data
    const usersResponse = await apiClient.getUsers({ limit: 5 });
    console.log("📋 Users:", usersResponse.data);

    // Get posts
    const postsResponse = await apiClient.getPosts({ limit: 3 });
    console.log("📝 Posts:", postsResponse.data);

    if (postsResponse.data.length > 0) {
      const firstPost = postsResponse.data[0];

      // Get post details
      const postDetails = await apiClient.getPost(firstPost.id);
      console.log("📄 Post Details:", postDetails);

      // Get post comments
      const commentsResponse = await apiClient.getPostComments(firstPost.id, {
        limit: 2,
      });
      console.log("💬 Comments:", commentsResponse.data);

      // Get post stats
      const stats = await apiClient.getPostStats(firstPost.id);
      console.log("📊 Post Stats:", stats);
    }

    // Get tags
    const tags = await apiClient.getTags();
    console.log("🏷️ Tags:", tags);

    console.log("✅ API demonstration complete!");
  } catch (error) {
    console.error("❌ API Error:", error);
  }
}

// Start the worker and run demo (for browser environment)
export async function initializeMockAPI() {
  try {
    // Start MSW worker
    await worker.start({
      onUnhandledRequest: "bypass", // Don't warn about unhandled requests
    });

    console.log("🔧 MSW worker started successfully");
    console.log("🗄️ Mock database ready with sample data");

    // Log some helpful info
    const users = db.user.getAll();
    const posts = db.post.getAll();

    console.log(`👥 Available test users: ${users.length}`);
    console.log(`📝 Available test posts: ${posts.length}`);
    console.log("🔐 Test credentials:");
    console.log('   Admin: username="admin", password="admin123"');
    console.log('   User: username="testuser", password="test123"');
    console.log('   All other users: password="password123"');

    return { apiClient, db, worker };
  } catch (error) {
    console.error("❌ Failed to initialize mock API:", error);
    throw error;
  }
}

// Export everything for convenience
export { db } from "./mocks";
