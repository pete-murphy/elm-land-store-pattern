# Mock API Documentation

## Overview

This mock API provides a comprehensive social platform backend with users, posts, comments, likes, tags, and follows. Built with `@mswjs/data` and MSW for realistic API mocking.

## Features

✅ **User Management** - Registration, profiles, roles  
✅ **Posts** - CRUD with status (draft/published), tags, views  
✅ **Comments** - Threaded comments with replies  
✅ **Social Features** - Likes, follows, user relationships  
✅ **Tagging System** - Categorize and filter posts  
✅ **Pagination** - All list endpoints support pagination  
✅ **Authentication** - Bearer token based auth  
✅ **Authorization** - Role-based permissions (admin, moderator, user)  
✅ **Search & Filtering** - Rich query capabilities

## Database Schema

### User

```typescript
{
  id: string (UUID)
  username: string
  email: string
  firstName: string
  lastName: string
  bio?: string
  avatarUrl: string
  role: 'admin' | 'moderator' | 'user'
  isActive: boolean
  createdAt: Date
  updatedAt: Date
}
```

### Post

```typescript
{
  id: string (UUID)
  title: string
  content: string
  excerpt: string
  slug: string
  status: 'draft' | 'published'
  author: User
  tags: Tag[]
  viewCount: number
  createdAt: Date
  updatedAt: Date
}
```

### Comment

```typescript
{
  id: string (UUID)
  content: string
  author: User
  post: Post
  parentComment?: Comment
  isDeleted: boolean
  createdAt: Date
  updatedAt: Date
}
```

### Tag

```typescript
{
  id: string (UUID)
  name: string
  slug: string
  description?: string
  color: string
  createdAt: Date
}
```

### Like

```typescript
{
  id: string(UUID);
  user: User;
  targetType: "post" | "comment";
  targetId: string;
  createdAt: Date;
}
```

### Follow

```typescript
{
  id: string(UUID);
  follower: User;
  following: User;
  createdAt: Date;
}
```

## Authentication

All protected endpoints require an `Authorization` header:

```
Authorization: Bearer {user-id}
```

The user ID should be a valid UUID from the database. For testing, you can use any user ID returned from `/api/users`.

## API Endpoints

### 👥 User Endpoints

#### `GET /api/me`

Get current authenticated user.

- **Auth**: Required
- **Response**: User object

#### `GET /api/users`

Get paginated list of users.

- **Query Parameters**:
  - `page` (number, default: 1)
  - `limit` (number, default: 10)
  - `search` (string) - Search username, firstName, lastName
- **Response**: Paginated user list

#### `GET /api/users/:id`

Get user by ID.

- **Response**: User object or 404

#### `GET /api/users/:id/posts`

Get user's posts (paginated).

- **Query Parameters**:
  - `page`, `limit` (pagination)
  - `status` (string) - Filter by 'draft' or 'published'
- **Response**: Paginated post list

#### `GET /api/users/:id/comments`

Get user's comments (paginated).

- **Query Parameters**: `page`, `limit`
- **Response**: Paginated comment list

#### `POST /api/users/:id/follow`

Follow a user.

- **Auth**: Required
- **Response**: Follow object (201) or error

#### `DELETE /api/users/:id/follow`

Unfollow a user.

- **Auth**: Required
- **Response**: 204 or 404

### 📝 Post Endpoints

#### `GET /api/posts`

Get paginated list of posts with advanced filtering.

- **Query Parameters**:
  - `page`, `limit` (pagination)
  - `tag` (string) - Filter by tag name
  - `author` (string) - Filter by author username
  - `status` (string) - Filter by status (defaults to 'published')
  - `search` (string) - Search title, content, excerpt
  - `sort` (string, default: 'createdAt') - Sort field
  - `order` ('asc' | 'desc', default: 'desc') - Sort order
- **Response**: Paginated post list

#### `GET /api/posts/:id`

Get post by ID (increments view count).

- **Response**: Post object or 404

#### `GET /api/posts/slug/:slug`

Get post by slug (increments view count).

- **Response**: Post object or 404

#### `POST /api/posts`

Create a new post.

- **Auth**: Required
- **Body**:
  ```json
  {
    "title": "string",
    "content": "string",
    "excerpt": "string (optional)",
    "status": "draft | published (default: draft)",
    "tagIds": ["tag-id-1", "tag-id-2"]
  }
  ```
- **Response**: Created post (201)

#### `PATCH /api/posts/:id`

Update a post (own posts only, or admin).

- **Auth**: Required
- **Body**: Partial post data
- **Response**: Updated post or 403/404

#### `DELETE /api/posts/:id`

Delete a post (own posts only, or admin).

- **Auth**: Required
- **Response**: 204 or 403/404

#### `POST /api/posts/:id/like`

Like/unlike a post (toggles).

- **Auth**: Required
- **Response**: `{ liked: boolean, like?: object }`

#### `GET /api/posts/:id/comments`

Get post's comments (paginated).

- **Query Parameters**:
  - `page`, `limit` (pagination)
  - `parent_only` (boolean) - Only top-level comments
- **Response**: Paginated comment list

#### `POST /api/posts/:id/comments`

Create a comment on a post.

- **Auth**: Required
- **Body**:
  ```json
  {
    "content": "string",
    "parentCommentId": "string (optional, for replies)"
  }
  ```
- **Response**: Created comment (201)

#### `GET /api/posts/:id/stats`

Get post statistics.

- **Response**:
  ```json
  {
    "views": 123,
    "likes": 45,
    "comments": 67
  }
  ```

### 💬 Comment Endpoints

#### `PATCH /api/comments/:id`

Update a comment (own comments only, or admin).

- **Auth**: Required
- **Body**: `{ "content": "string" }`
- **Response**: Updated comment or 403/404

#### `DELETE /api/comments/:id`

Delete a comment (soft delete - marks as deleted).

- **Auth**: Required
- **Response**: 204 or 403/404

#### `POST /api/comments/:id/like`

Like/unlike a comment (toggles).

- **Auth**: Required
- **Response**: `{ liked: boolean, like?: object }`

### 🏷️ Tag Endpoints

#### `GET /api/tags`

Get all tags.

- **Query Parameters**:
  - `search` (string) - Search tag names
- **Response**: Tag array

#### `GET /api/tags/:id/posts`

Get posts by tag (paginated).

- **Query Parameters**: `page`, `limit`
- **Response**: Paginated post list

## Pagination Response Format

All paginated endpoints return:

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 10,
    "totalPages": 5,
    "totalCount": 50,
    "hasNextPage": true,
    "hasPreviousPage": false
  }
}
```

## Error Responses

- **400**: Bad Request - Invalid input
- **401**: Unauthorized - Missing or invalid auth
- **403**: Forbidden - Insufficient permissions
- **404**: Not Found - Resource doesn't exist
- **409**: Conflict - Resource already exists

## Sample Data

The mock database is seeded with:

- 15 users (mix of roles)
- 50 posts (published and drafts)
- 150 comments (including replies)
- 10 tags
- 200 likes
- 80 follow relationships

## Usage Examples

### Get published posts with pagination

```javascript
fetch("/api/posts?page=1&limit=5&status=published");
```

### Get post by slug (SEO-friendly URLs)

```javascript
// Frontend route: /posts/my-awesome-post-title
const slug = "my-awesome-post-title"; // from URL params
fetch(`/api/posts/slug/${slug}`);
```

### Search posts by keyword

```javascript
fetch("/api/posts?search=javascript&sort=viewCount&order=desc");
```

### Create a new post

```javascript
fetch("/api/posts", {
  method: "POST",
  headers: {
    Authorization: "Bearer user-id-here",
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    title: "My New Post",
    content: "Post content here...",
    status: "published",
    tagIds: ["tag-id-1"],
  }),
});
```

### Get user's followers/following

```javascript
// Get who user follows
fetch("/api/users/user-id/following");

// Get user's followers
fetch("/api/users/user-id/followers");
```

### Like a post

```javascript
fetch("/api/posts/post-id/like", {
  method: "POST",
  headers: {
    Authorization: "Bearer user-id-here",
  },
});
```

## Notes

- All dates are JavaScript Date objects
- UUIDs are generated using faker
- User avatars are generated URLs
- Content is lorem ipsum for demo purposes
- Authentication is simplified (no real JWT/sessions)
- Data persists only during the session (resets on reload)
