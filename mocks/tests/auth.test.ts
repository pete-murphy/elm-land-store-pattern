import { describe, it, expect, beforeEach } from "vitest";
import { getAdminUser, getInactiveUser, getTestUser } from "./setup";
import { db } from "../mocks"; // Import db to verify token revocation

const API_BASE = "http://localhost/api"; // Assuming tests run against localhost

// Helper to log in a user and get tokens
async function loginUser(usernameOrEmail: string, password?: string) {
  const loginResponse = await fetch(`${API_BASE}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ usernameOrEmail, password: password || "test123" }),
  });
  return loginResponse.json();
}

describe("Authentication API", () => {
  let testUser: any;
  let adminUser: any;
  let inactiveUser: any;

  beforeEach(() => {
    testUser = getTestUser();
    adminUser = getAdminUser();
    inactiveUser = getInactiveUser();
  });

  describe("POST /api/auth/login", () => {
    it("should login with username and correct password", async () => {
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usernameOrEmail: testUser.username,
          password: "test123",
        }),
      });
      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.accessToken).toBeDefined();
      expect(data.refreshToken).toBeDefined();
      expect(data.user.id).toBe(testUser.id);
    });

    it("should login with email and correct password", async () => {
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usernameOrEmail: testUser.email,
          password: "test123",
        }),
      });
      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.user.id).toBe(testUser.id);
    });

    it("should return 401 for incorrect password", async () => {
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usernameOrEmail: testUser.username,
          password: "wrongpassword",
        }),
      });
      expect(response.status).toBe(401);
    });

    it("should return 401 for non-existent user", async () => {
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usernameOrEmail: "nonexistentuser",
          password: "password",
        }),
      });
      expect(response.status).toBe(401);
    });

    it("should return 403 for inactive user", async () => {
      const response = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usernameOrEmail: inactiveUser.username,
          password: "inactive123",
        }),
      });
      expect(response.status).toBe(403);
    });
  });

  describe("POST /api/auth/refresh", () => {
    it("should refresh tokens with a valid refresh token", async () => {
      const loginData = await loginUser(testUser.username);
      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: loginData.refreshToken }),
      });
      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.accessToken).toBeDefined();
      expect(data.refreshToken).toBeDefined();
      // New tokens should be different
      expect(data.accessToken).not.toBe(loginData.accessToken);
      expect(data.refreshToken).not.toBe(loginData.refreshToken);
    });

    it("should return 401 for invalid or expired refresh token", async () => {
      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: "invalidtoken" }),
      });
      expect(response.status).toBe(401);
    });

    it("should return 401 if refresh token is revoked", async () => {
      const loginData = await loginUser(testUser.username);
      // Simulate token revocation by removing it from the db
      const tokenEntry = db.refreshToken.findFirst({
        where: { token: { equals: loginData.refreshToken } },
      });
      if (tokenEntry) {
        db.refreshToken.update({
          where: { id: { equals: tokenEntry.id } },
          data: { isRevoked: true },
        });
      }

      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: loginData.refreshToken }),
      });
      expect(response.status).toBe(401);
    });
  });

  describe("POST /api/auth/logout", () => {
    it("should logout user and revoke refresh token", async () => {
      const loginData = await loginUser(testUser.username);
      const response = await fetch(`${API_BASE}/auth/logout`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: loginData.refreshToken }),
      });
      expect(response.status).toBe(204);

      // Verify token is revoked
      const tokenEntry = db.refreshToken.findFirst({
        where: { token: { equals: loginData.refreshToken } },
      });
      expect(tokenEntry?.isRevoked).toBe(true);

      // Attempting to refresh with revoked token should fail
      const refreshResponse = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: loginData.refreshToken }),
      });
      expect(refreshResponse.status).toBe(401);
    });

    it("should return 400 if refresh token is missing", async () => {
      const response = await fetch(`${API_BASE}/auth/logout`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}), // Missing refreshToken
      });
      expect(response.status).toBe(400);
    });
  });

  describe("GET /api/auth/verify", () => {
    it("should verify a valid access token", async () => {
      const loginData = await loginUser(testUser.username);
      const response = await fetch(`${API_BASE}/auth/verify`, {
        headers: { Authorization: `Bearer ${loginData.accessToken}` },
      });
      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.message).toBe("Token is valid");
      expect(data.user.id).toBe(testUser.id);
    });

    it("should return 401 for invalid access token", async () => {
      const response = await fetch(`${API_BASE}/auth/verify`, {
        headers: { Authorization: "Bearer invalidtoken" },
      });
      expect(response.status).toBe(401);
    });

    it("should return 401 if no token is provided", async () => {
      const response = await fetch(`${API_BASE}/auth/verify`);
      expect(response.status).toBe(401);
    });
  });

  describe("POST /api/auth/logout-all", () => {
    it("should logout user from all devices by revoking all refresh tokens", async () => {
      // Login twice to simulate two devices
      const loginData1 = await loginUser(testUser.username);
      const loginData2 = await loginUser(testUser.username);

      const response = await fetch(`${API_BASE}/auth/logout-all`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${loginData1.accessToken}`,
        },
      });
      expect(response.status).toBe(204);

      // Verify both tokens are revoked
      const tokenEntry1 = db.refreshToken.findFirst({
        where: { token: { equals: loginData1.refreshToken } },
      });
      expect(tokenEntry1?.isRevoked).toBe(true);

      const tokenEntry2 = db.refreshToken.findFirst({
        where: { token: { equals: loginData2.refreshToken } },
      });
      expect(tokenEntry2?.isRevoked).toBe(true);
    });

    it("should require authentication", async () => {
      const response = await fetch(`${API_BASE}/auth/logout-all`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      expect(response.status).toBe(401);
    });
  });
});
