# 🔐 Authentication Guide

This mock API includes a complete JWT-based authentication system with access tokens, refresh tokens, and secure endpoints.

## Overview

The authentication system provides:

- **JWT Access Tokens** (15-minute expiration) for API access
- **Refresh Tokens** (7-day expiration) for token renewal
- **Secure password verification** (simplified for demo purposes)
- **Token revocation** for logout functionality
- **Automatic token refresh** in the API client

## Test Credentials

For testing purposes, the following accounts are pre-created:

| Username        | Email               | Password      | Role  |
| --------------- | ------------------- | ------------- | ----- |
| `admin`         | `admin@example.com` | `admin123`    | admin |
| `testuser`      | `test@example.com`  | `test123`     | user  |
| All other users | Various             | `password123` | user  |

## Authentication Endpoints

### POST `/api/auth/login`

Login with username/email and password.

**Request Body:**

```json
{
  "username": "testuser", // OR use "email" instead
  "password": "test123"
}
```

**Response:**

```json
{
  "user": {
    "id": "user-id",
    "username": "testuser",
    "email": "test@example.com"
    // ... other user fields (password excluded)
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 900 // 15 minutes in seconds
}
```

### POST `/api/auth/refresh`

Refresh an expired access token using a refresh token.

**Request Body:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 900
}
```

### POST `/api/auth/logout`

Logout and revoke the refresh token.

**Request Body:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**

```json
{
  "message": "Logged out successfully"
}
```

### POST `/api/auth/logout-all`

Logout from all devices by revoking all refresh tokens for the user.

**Headers:**

```
Authorization: Bearer <access-token>
```

**Response:**

```json
{
  "message": "Logged out from all devices successfully",
  "revokedTokens": 3
}
```

### GET `/api/auth/verify`

Verify if the current access token is valid.

**Headers:**

```
Authorization: Bearer <access-token>
```

**Response:**

```json
{
  "user": {
    "id": "user-id",
    "username": "testuser"
    // ... user data
  },
  "valid": true
}
```

## Using the API Client

The `MockApiClient` class provides convenient methods for authentication:

### Login

```typescript
import { apiClient } from "./src/mock-setup-example";

// Login with username
const result = await apiClient.login({
  username: "testuser",
  password: "test123",
});

// Login with email
const result = await apiClient.login({
  email: "test@example.com",
  password: "test123",
});

console.log("Logged in as:", result.user.username);
```

### Check Authentication Status

```typescript
if (apiClient.isAuthenticated()) {
  console.log("User is logged in");
} else {
  console.log("User needs to login");
}
```

### Automatic Token Refresh

The API client automatically handles token refresh when making authenticated requests:

```typescript
// This will automatically refresh the token if needed
const currentUser = await apiClient.getCurrentUser();
const posts = await apiClient.getPosts();
```

### Manual Token Operations

```typescript
// Manually refresh token
const tokens = await apiClient.refreshAccessToken();

// Verify current token
const verification = await apiClient.verifyToken();

// Logout
await apiClient.logout();

// Logout from all devices
await apiClient.logoutAll();
```

## Protected Endpoints

The following endpoints require authentication (Bearer token in Authorization header):

### User Operations

- `GET /api/me` - Get current user
- `POST /api/users/:id/follow` - Follow user
- `DELETE /api/users/:id/follow` - Unfollow user

### Post Operations

- `POST /api/posts` - Create post
- `PATCH /api/posts/:id` - Update post (author/admin only)
- `DELETE /api/posts/:id` - Delete post (author/admin only)
- `POST /api/posts/:id/like` - Like/unlike post
- `POST /api/posts/:id/comments` - Create comment

### Comment Operations

- `PATCH /api/comments/:id` - Update comment (author/admin only)
- `DELETE /api/comments/:id` - Delete comment (author/admin only)
- `POST /api/comments/:id/like` - Like/unlike comment

### Authentication Required

- `POST /api/auth/logout-all` - Logout all devices
- `GET /api/auth/verify` - Verify token

## Authorization Levels

### User Permissions

- Users can edit/delete their own posts and comments
- Users can like posts and comments
- Users can follow/unfollow other users

### Admin Permissions

- Admins can edit/delete any posts and comments
- Admins have all user permissions

### Moderator Permissions

- Same as admin (for this demo)

## Token Security

### Access Tokens

- **Expiration:** 15 minutes
- **Purpose:** API access authorization
- **Storage:** Should be stored securely (memory, secure storage)
- **Transmission:** Always sent in Authorization header

### Refresh Tokens

- **Expiration:** 7 days
- **Purpose:** Renewing access tokens
- **Storage:** Stored in database, can be revoked
- **Security:** Should be stored securely and transmitted only when refreshing

### Best Practices

1. **Store tokens securely** - The demo uses localStorage for simplicity, but use secure storage in production
2. **Handle token expiration** - The API client automatically handles this
3. **Logout properly** - Always call logout to revoke refresh tokens
4. **Use HTTPS** - In production, always use HTTPS for token transmission

## Error Handling

### Authentication Errors

```json
// Invalid credentials
{
  "error": "Invalid credentials"
}

// Token expired
{
  "error": "Refresh token expired"
}

// Missing authorization
{
  "error": "Authorization header required"
}
```

### Handling in Code

```typescript
try {
  const result = await apiClient.login({
    username: "wronguser",
    password: "wrongpass",
  });
} catch (error) {
  console.error("Login failed:", error.message);
  // Handle login error (show message to user, etc.)
}

try {
  const posts = await apiClient.getPosts();
} catch (error) {
  if (error.message.includes("Authentication failed")) {
    // Token expired and refresh failed - redirect to login
    window.location.href = "/login";
  }
}
```

## Example Usage

### Complete Authentication Flow

```typescript
import { apiClient, demonstrateAuthentication } from "./src/mock-setup-example";

async function authenticationExample() {
  try {
    // 1. Login
    console.log("Logging in...");
    const loginResult = await apiClient.login({
      username: "testuser",
      password: "test123",
    });
    console.log("✅ Logged in as:", loginResult.user.username);

    // 2. Make authenticated requests
    const currentUser = await apiClient.getCurrentUser();
    console.log("Current user:", currentUser.username);

    // 3. Create content (requires auth)
    const newPost = await apiClient.createPost({
      title: "My Authenticated Post",
      content: "This post was created with JWT authentication!",
      status: "published",
    });
    console.log("Created post:", newPost.title);

    // 4. Verify token
    const verification = await apiClient.verifyToken();
    console.log("Token is valid:", verification.valid);

    // 5. Logout
    await apiClient.logout();
    console.log("✅ Logged out successfully");
  } catch (error) {
    console.error("❌ Authentication error:", error.message);
  }
}

// Run the example
authenticationExample();

// Or use the built-in demo
demonstrateAuthentication();
```

## Development Notes

- **JWT Secret:** Uses a hardcoded secret for demo purposes. In production, use a secure, randomly generated secret.
- **Password Hashing:** Simplified for demo. In production, use bcrypt or similar.
- **Token Storage:** Demo uses localStorage. In production, consider more secure storage options.
- **Error Messages:** Generic messages to prevent information leakage in production.

This authentication system provides a solid foundation for testing authentication flows in your application while maintaining security best practices.
