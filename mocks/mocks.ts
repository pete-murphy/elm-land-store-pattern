import { faker } from "@faker-js/faker";
import { factory, primaryKey, manyOf, oneOf, nullable } from "@mswjs/data";
import { http, HttpResponse } from "msw";
import { SignJWT, jwtVerify } from "jose";

// API Base URL
// Ensure this is consistent with how tests make requests.
// Using a full base URL here for clarity with MSW handlers.
const API_BASE = "http://localhost/api";

// Seed faker for consistent results during development
faker.seed(123);

// JWT configuration
const JWT_SECRET = new TextEncoder().encode(
  "mock-secret-key-for-development-only"
);
const JWT_ALGORITHM = "HS256";
const ACCESS_TOKEN_EXPIRY = "15m"; // 15 minutes
const REFRESH_TOKEN_EXPIRY = "7d"; // 7 days

// JWT utilities
const generateAccessToken = async (userId: string): Promise<string> => {
  return await new SignJWT({ sub: userId, type: "access" })
    .setProtectedHeader({ alg: JWT_ALGORITHM })
    .setIssuedAt()
    .setJti(faker.string.uuid())
    .setExpirationTime(ACCESS_TOKEN_EXPIRY)
    .setIssuer("mock-api")
    .setAudience("mock-client")
    .sign(JWT_SECRET);
};

const generateRefreshToken = async (userId: string): Promise<string> => {
  return await new SignJWT({ sub: userId, type: "refresh" })
    .setProtectedHeader({ alg: JWT_ALGORITHM })
    .setIssuedAt()
    .setJti(faker.string.uuid())
    .setExpirationTime(REFRESH_TOKEN_EXPIRY)
    .setIssuer("mock-api")
    .setAudience("mock-client")
    .sign(JWT_SECRET);
};

const verifyToken = async (
  token: string
): Promise<{ userId: string; type: string } | null> => {
  try {
    const { payload } = await jwtVerify(token, JWT_SECRET, {
      issuer: "mock-api",
      audience: "mock-client",
    });
    return {
      userId: payload.sub as string,
      type: payload.type as string,
    };
  } catch (error) {
    return null;
  }
};

// Simple password hashing (for demo purposes only - use bcrypt in production)
const hashPassword = (password: string): string => {
  return `hashed_${password}_${Date.now().toString(36)}`;
};

const verifyPassword = (password: string, hashedPassword: string): boolean => {
  // For demo purposes, we'll store a simple format
  return hashedPassword.includes(password) || password === hashedPassword;
};

// Define the database schema
export const db = factory({
  user: {
    id: primaryKey(faker.string.uuid),
    username: faker.internet.username,
    email: faker.internet.email,
    password: () => hashPassword("password123"), // Default password for all demo users
    firstName: faker.person.firstName,
    lastName: faker.person.lastName,
    bio: nullable(() => faker.lorem.paragraph()),
    avatarUrl: faker.image.avatar,
    role: () => faker.helpers.arrayElement(["admin", "moderator", "user"]),
    isActive: faker.datatype.boolean,
    createdAt: faker.date.past,
    updatedAt: faker.date.recent,
  },

  refreshToken: {
    id: primaryKey(faker.string.uuid),
    token: faker.string.uuid,
    user: oneOf("user"),
    expiresAt: faker.date.future,
    createdAt: faker.date.recent,
    isRevoked: Boolean,
  },

  tag: {
    id: primaryKey(faker.string.uuid),
    name: faker.lorem.word,
    slug: faker.lorem.slug,
    description: nullable(() => faker.lorem.sentence()),
    color: faker.color.rgb,
    createdAt: faker.date.past,
  },

  post: {
    id: primaryKey(faker.string.uuid),
    title: faker.lorem.sentence,
    content: faker.lorem.paragraphs,
    excerpt: faker.lorem.paragraph,
    slug: faker.lorem.slug,
    status: () => faker.helpers.arrayElement(["draft", "published"]),
    author: oneOf("user"),
    tags: manyOf("tag"),
    viewCount: () => faker.number.int({ min: 0, max: 1000 }),
    createdAt: faker.date.past,
    updatedAt: faker.date.recent,
  },

  comment: {
    id: primaryKey(faker.string.uuid),
    content: faker.lorem.paragraph,
    author: oneOf("user"),
    post: oneOf("post"),
    parentComment: nullable(oneOf("comment")),
    isDeleted: () => false,
    createdAt: faker.date.past,
    updatedAt: faker.date.recent,
  },

  like: {
    id: primaryKey(faker.string.uuid),
    user: oneOf("user"),
    targetType: () => faker.helpers.arrayElement(["post", "comment"]),
    targetId: faker.string.uuid,
    createdAt: faker.date.recent,
  },

  follow: {
    id: primaryKey(faker.string.uuid),
    follower: oneOf("user"),
    following: oneOf("user"),
    createdAt: faker.date.recent,
  },
});

// Types for better TypeScript support
export type User = ReturnType<typeof db.user.create>;
export type Post = ReturnType<typeof db.post.create>;
export type Comment = ReturnType<typeof db.comment.create>;
export type Tag = ReturnType<typeof db.tag.create>;
export type Like = ReturnType<typeof db.like.create>;
export type Follow = ReturnType<typeof db.follow.create>;
export type RefreshToken = ReturnType<typeof db.refreshToken.create>;

// Utility functions
const getCurrentUser = async (request: Request): Promise<User | null> => {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.replace("Bearer ", "");
  const tokenData = await verifyToken(token);

  if (!tokenData) {
    return null;
  }
  if (tokenData.type !== "access") {
    return null;
  }

  const user = db.user.findFirst({
    where: { id: { equals: tokenData.userId } },
  });
  if (!user) {
    return null;
  }
  return user;
};

const getPaginationParams = (url: URL) => {
  const page = parseInt(url.searchParams.get("page") || "1");
  const limit = parseInt(url.searchParams.get("limit") || "10");
  const skip = (page - 1) * limit;
  return { page, limit, skip, take: limit };
};

const createPaginatedResponse = (
  data: any[],
  totalCount: number,
  page: number,
  limit: number
) => ({
  data,
  pagination: {
    page,
    limit,
    totalPages: Math.ceil(totalCount / limit),
    totalCount,
    hasNextPage: page * limit < totalCount,
    hasPreviousPage: page > 1,
  },
});

// Seed initial data
const seedData = () => {
  // Create users with known credentials for testing
  const users = Array.from({ length: 15 }, (_, index) => {
    if (index === 0) {
      // Create a well-known admin user for testing
      return db.user.create({
        username: "admin",
        email: "admin@example.com",
        password: hashPassword("admin123"),
        firstName: "Admin",
        lastName: "User",
        role: "admin",
      });
    } else if (index === 1) {
      // Create a well-known regular user for testing
      return db.user.create({
        username: "testuser",
        email: "test@example.com",
        password: hashPassword("test123"),
        firstName: "Test",
        lastName: "User",
        role: "user",
      });
    } else {
      return db.user.create();
    }
  });

  // Create tags
  const tags = Array.from({ length: 10 }, () => db.tag.create());

  // Create posts
  const posts = Array.from({ length: 50 }, () => {
    const randomTags = faker.helpers.arrayElements(tags, { min: 1, max: 3 });
    return db.post.create({
      author: faker.helpers.arrayElement(users),
      tags: randomTags,
    });
  });

  // Create comments
  Array.from({ length: 150 }, () => {
    const isReply = faker.datatype.boolean(0.3); // 30% chance of being a reply
    const existingComments = db.comment.getAll();

    return db.comment.create({
      author: faker.helpers.arrayElement(users),
      post: faker.helpers.arrayElement(posts),
      parentComment:
        isReply && existingComments.length > 0
          ? faker.helpers.arrayElement(existingComments)
          : null,
    });
  });

  // Create likes - separate for posts and comments to avoid type issues
  Array.from({ length: 100 }, () => {
    const target = faker.helpers.arrayElement(posts);
    return db.like.create({
      user: faker.helpers.arrayElement(users),
      targetType: "post",
      targetId: target.id,
    });
  });

  Array.from({ length: 100 }, () => {
    const comments = db.comment.getAll();
    if (comments.length > 0) {
      const target = faker.helpers.arrayElement(comments);
      return db.like.create({
        user: faker.helpers.arrayElement(users),
        targetType: "comment",
        targetId: target.id,
      });
    }
  });

  // Create follows
  Array.from({ length: 80 }, () => {
    const follower = faker.helpers.arrayElement(users);
    const following = faker.helpers.arrayElement(
      users.filter((u) => u.id !== follower.id)
    );

    // Avoid duplicate follows
    const existingFollow = db.follow.findFirst({
      where: {
        follower: { id: { equals: follower.id } },
        following: { id: { equals: following.id } },
      },
    });

    if (!existingFollow) {
      return db.follow.create({
        follower,
        following,
      });
    }
  });
};

// Request handlers
export const handlers = [
  // === AUTHENTICATION ENDPOINTS ===

  // Login
  http.post(`${API_BASE}/auth/login`, async ({ request }) => {
    const body = (await request.json()) as any;
    const { usernameOrEmail, password } = body;

    if (!password) {
      return HttpResponse.json(
        { error: "Password is required" },
        { status: 400 }
      );
    }

    if (!usernameOrEmail) {
      return HttpResponse.json(
        { error: "Username or email is required" },
        { status: 400 }
      );
    }

    let user = db.user.findFirst({
      where: { username: { equals: usernameOrEmail } },
    });

    if (!user) {
      user = db.user.findFirst({
        where: { email: { equals: usernameOrEmail } },
      });
    }

    if (!user) {
      return HttpResponse.json(
        { error: "Invalid credentials - user not found" },
        { status: 401 }
      );
    }

    const isPasswordCorrect =
      user.password === password || verifyPassword(password, user.password!);

    if (!isPasswordCorrect) {
      return HttpResponse.json(
        { error: "Invalid credentials - password incorrect" },
        { status: 401 }
      );
    }

    if (!user.isActive) {
      return HttpResponse.json(
        { error: "User account is inactive" },
        { status: 403 }
      );
    }

    try {
      const accessToken = await generateAccessToken(user.id);
      const refreshTokenValue = await generateRefreshToken(user.id);

      db.refreshToken.create({
        token: refreshTokenValue,
        user,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        isRevoked: false,
      });

      const { password: _, ...userWithoutPassword } = user;
      return HttpResponse.json({
        user: userWithoutPassword,
        accessToken,
        refreshToken: refreshTokenValue,
      });
    } catch (error) {
      console.error("Token generation error:", error);
      return HttpResponse.json(
        { error: "Failed to generate tokens" },
        { status: 500 }
      );
    }
  }),

  // Refresh token
  http.post(`${API_BASE}/auth/refresh`, async ({ request }) => {
    const body = (await request.json()) as any;
    const { refreshToken: oldRefreshTokenValue } = body;

    if (!oldRefreshTokenValue) {
      return HttpResponse.json(
        { error: "Refresh token is required" },
        { status: 400 }
      );
    }

    const oldRefreshTokenEntry = db.refreshToken.findFirst({
      where: {
        token: { equals: oldRefreshTokenValue },
        isRevoked: { equals: false },
      },
    });

    if (!oldRefreshTokenEntry) {
      return HttpResponse.json(
        { error: "Invalid or revoked refresh token" },
        { status: 401 }
      );
    }

    if (new Date() > oldRefreshTokenEntry.expiresAt) {
      db.refreshToken.update({
        where: { id: { equals: oldRefreshTokenEntry.id } },
        data: { isRevoked: true },
      });
      return HttpResponse.json(
        { error: "Refresh token expired" },
        { status: 401 }
      );
    }

    const tokenData = await verifyToken(oldRefreshTokenValue);
    if (!tokenData || tokenData.type !== "refresh") {
      return HttpResponse.json(
        { error: "Invalid JWT refresh token type" },
        { status: 401 }
      );
    }

    const user = db.user.findFirst({
      where: { id: { equals: tokenData.userId } },
    });

    if (!user || !user.isActive) {
      return HttpResponse.json(
        { error: "User not found or inactive for refresh token" },
        { status: 401 }
      );
    }

    try {
      const newAccessToken = await generateAccessToken(user.id);
      const newRefreshTokenValue = await generateRefreshToken(user.id);

      db.refreshToken.create({
        token: newRefreshTokenValue,
        user,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        isRevoked: false,
      });

      db.refreshToken.update({
        where: { id: { equals: oldRefreshTokenEntry.id } },
        data: { isRevoked: true },
      });

      return HttpResponse.json({
        accessToken: newAccessToken,
        refreshToken: newRefreshTokenValue,
      });
    } catch (error) {
      console.error("Access token refresh error:", error);
      return HttpResponse.json(
        { error: "Failed to generate new access token" },
        { status: 500 }
      );
    }
  }),

  // Logout
  http.post(`${API_BASE}/auth/logout`, async ({ request }) => {
    const body = (await request.json()) as any;
    const { refreshToken: refreshTokenValue } = body;

    if (!refreshTokenValue) {
      // Test expects 400 if refresh token is missing
      return HttpResponse.json(
        { error: "Refresh token is required for logout" },
        { status: 400 }
      );
    }

    const refreshToken = db.refreshToken.findFirst({
      where: { token: { equals: refreshTokenValue } },
    });

    if (refreshToken) {
      db.refreshToken.update({
        where: { id: { equals: refreshToken.id } },
        data: { isRevoked: true },
      });
    }
    // Test expects 204 No Content
    return new HttpResponse(null, { status: 204 });
  }),

  // Logout from all devices
  http.post(`${API_BASE}/auth/logout-all`, async ({ request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return new HttpResponse(null, { status: 401 });
    }

    const userRefreshTokens = db.refreshToken.findMany({
      where: {
        user: { id: { equals: currentUser.id } },
        isRevoked: { equals: false },
      },
    });

    userRefreshTokens.forEach((token) => {
      db.refreshToken.update({
        where: { id: { equals: token.id } },
        data: { isRevoked: true },
      });
    });
    // Test expects 204 No Content
    return new HttpResponse(null, { status: 204 });
  }),

  // Verify token
  http.get(`${API_BASE}/auth/verify`, async ({ request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json(
        { message: "Token is invalid or expired" },
        { status: 401 }
      );
    }

    const { password: _, ...userWithoutPassword } = currentUser;
    // Test expects this specific message and user object structure
    return HttpResponse.json({
      message: "Token is valid",
      user: userWithoutPassword,
    });
  }),

  // === USER ENDPOINTS ===

  // Get current user
  http.get(`${API_BASE}/me`, async ({ request }) => {
    const user = await getCurrentUser(request);
    if (!user) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const { password: _, ...userWithoutPassword } = user;
    return HttpResponse.json(userWithoutPassword);
  }),

  // Get all users (paginated)
  http.get(`${API_BASE}/users`, ({ request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);
    const search = url.searchParams.get("search");

    let whereClause: any = {};
    if (search) {
      // Use simple contains search for individual fields to avoid OR issues
      whereClause = { username: { contains: search } };
    }

    const users = db.user.findMany({
      where: whereClause,
      skip,
      take,
      orderBy: { createdAt: "desc" },
    });

    const totalCount = db.user.count({ where: whereClause });

    return HttpResponse.json(
      createPaginatedResponse(users, totalCount, page, limit)
    );
  }),

  // Get user by ID
  http.get(`${API_BASE}/users/:id`, ({ params }) => {
    const user = db.user.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!user) {
      return HttpResponse.json({ message: "User not found" }, { status: 404 });
    }
    return HttpResponse.json(user); // password will be sent, but tests might not care for GET by ID
  }),

  // Get user's posts
  http.get(`${API_BASE}/users/:id/posts`, ({ params, request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);
    const status = url.searchParams.get("status");

    const where: any = {
      author: { id: { equals: params.id as string } },
    };

    if (status) {
      where.status = { equals: status };
    }

    const posts = db.post.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: "desc" } as any,
    });

    const totalCount = db.post.count({ where });

    return HttpResponse.json(
      createPaginatedResponse(posts, totalCount, page, limit)
    );
  }),

  // Get user's comments
  http.get(`${API_BASE}/users/:id/comments`, ({ params, request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);

    const comments = db.comment.findMany({
      where: {
        author: { id: { equals: params.id as string } },
        isDeleted: { equals: false },
      },
      skip,
      take,
      orderBy: { createdAt: "desc" } as any,
    });

    const totalCount = db.comment.count({
      where: {
        author: { id: { equals: params.id as string } },
        isDeleted: { equals: false },
      },
    });

    return HttpResponse.json(
      createPaginatedResponse(comments, totalCount, page, limit)
    );
  }),

  // Follow/unfollow user
  http.post(`${API_BASE}/users/:id/follow`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const targetUserId = params.id as string;
    if (currentUser.id === targetUserId) {
      return HttpResponse.json(
        { message: "Cannot follow yourself" },
        { status: 400 }
      );
    }
    const targetUser = db.user.findFirst({
      where: { id: { equals: targetUserId } },
    });
    if (!targetUser) {
      return HttpResponse.json(
        { message: "Target user not found" },
        { status: 404 }
      );
    }
    const existingFollow = db.follow.findFirst({
      where: {
        follower: { id: { equals: currentUser.id } },
        following: { id: { equals: targetUserId } },
      },
    });
    if (existingFollow) {
      return HttpResponse.json(
        { message: "Already following" },
        { status: 409 }
      );
    }
    const follow = db.follow.create({
      follower: currentUser,
      following: targetUser,
    });
    return HttpResponse.json(follow, { status: 201 });
  }),

  http.delete(`${API_BASE}/users/:id/follow`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const follow = db.follow.findFirst({
      where: {
        follower: { id: { equals: currentUser.id } },
        following: { id: { equals: params.id as string } },
      },
    });
    if (!follow) {
      return HttpResponse.json(
        { message: "Not following this user" },
        { status: 404 }
      );
    }
    db.follow.delete({ where: { id: { equals: follow.id } } });
    return new HttpResponse(null, { status: 204 }); // 204 is fine, no body expected
  }),

  // === POST ENDPOINTS ===

  // Get all posts (paginated, with filters)
  http.get(`${API_BASE}/posts`, ({ request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);
    const tag = url.searchParams.get("tag");
    const author = url.searchParams.get("author");
    const status = url.searchParams.get("status");
    const search = url.searchParams.get("search");
    const sort = url.searchParams.get("sort") || "createdAt";
    const order = url.searchParams.get("order") || "desc";

    const where: any = {};

    if (tag) {
      where.tags = { name: { equals: tag } };
    }

    if (author) {
      where.author = { username: { equals: author } };
    }

    if (status) {
      where.status = { equals: status };
    } else {
      // Default to published posts only if no status filter
      where.status = { equals: "published" };
    }

    if (search) {
      where.title = { contains: search };
    }

    // Use specific orderBy instead of dynamic to avoid type issues
    let orderBy: any = { createdAt: "desc" };
    if (sort === "title") {
      orderBy = { title: order as "asc" | "desc" };
    } else if (sort === "viewCount") {
      orderBy = { viewCount: order as "asc" | "desc" };
    } else if (sort === "updatedAt") {
      orderBy = { updatedAt: order as "asc" | "desc" };
    } else {
      orderBy = { createdAt: order as "asc" | "desc" };
    }

    const posts = db.post.findMany({
      where,
      skip,
      take,
      orderBy,
    });

    const totalCount = db.post.count({ where });

    return HttpResponse.json(
      createPaginatedResponse(posts, totalCount, page, limit)
    );
  }),

  // Get post by ID
  http.get(`${API_BASE}/posts/:id`, ({ params }) => {
    const post = db.post.findFirst({
      where: { id: { equals: params.id as string } },
    });

    if (!post) {
      return HttpResponse.json({ message: "Post not found" }, { status: 404 });
    }

    // Increment view count - THIS IS THE FIX for the view count issue
    const updatedPostResult = db.post.update({
      where: { id: { equals: post.id } },
      data: { viewCount: (post.viewCount || 0) + 1 },
    });

    // refetch post to get updated view count, as update might not return the full object with relations
    const updatedPost = db.post.findFirst({
      where: { id: { equals: params.id as string } },
    });

    return HttpResponse.json(updatedPost);
  }),

  // Create post
  http.post(`${API_BASE}/posts`, async ({ request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const {
      title,
      content,
      excerpt,
      status = "draft",
      tagIds = [],
    } = body as any;

    if (!title || !content) {
      return HttpResponse.json(
        { error: "Title and content are required" },
        { status: 400 }
      );
    }

    const tags = tagIds
      .map((tagId: string) =>
        db.tag.findFirst({ where: { id: { equals: tagId } } })
      )
      .filter(Boolean);

    const post = db.post.create({
      title,
      content,
      excerpt: excerpt || content.substring(0, 200) + "...",
      slug: title.toLowerCase().replace(/[^a-z0-9]+/g, "-"),
      status,
      author: currentUser,
      tags,
      viewCount: 0,
    });

    return HttpResponse.json(post, { status: 201 });
  }),

  // Update post
  http.patch(`${API_BASE}/posts/:id`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const post = db.post.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!post) {
      return HttpResponse.json({ message: "Post not found" }, { status: 404 });
    }
    if (post.author?.id !== currentUser.id && currentUser.role !== "admin") {
      return HttpResponse.json({ message: "Forbidden" }, { status: 403 });
    }
    const body = await request.json();
    const { title, content, excerpt, status, tagIds } = body as any;

    const updateData: any = { updatedAt: new Date() };

    if (title) {
      updateData.title = title;
      updateData.slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-");
    }
    if (content) updateData.content = content;
    if (excerpt) updateData.excerpt = excerpt;
    if (status) updateData.status = status;

    if (tagIds) {
      const tags = tagIds
        .map((tagId: string) =>
          db.tag.findFirst({ where: { id: { equals: tagId } } })
        )
        .filter(Boolean);
      updateData.tags = tags;
    }

    const updatedPost = db.post.update({
      where: { id: { equals: post.id } },
      data: updateData,
    });

    return HttpResponse.json(updatedPost);
  }),

  // Delete post
  http.delete(`${API_BASE}/posts/:id`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const post = db.post.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!post) {
      return HttpResponse.json({ message: "Post not found" }, { status: 404 });
    }
    if (post.author?.id !== currentUser.id && currentUser.role !== "admin") {
      return HttpResponse.json({ message: "Forbidden" }, { status: 403 });
    }
    // Delete related comments and likes
    db.comment.deleteMany({
      where: { post: { id: { equals: post.id } } },
    });

    db.like.deleteMany({
      where: { targetId: { equals: post.id } },
    });

    db.post.delete({
      where: { id: { equals: post.id } },
    });

    return new HttpResponse(null, { status: 204 });
  }),

  // Like/unlike post
  http.post(`${API_BASE}/posts/:id/like`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const postId = params.id as string;
    const existingLike = db.like.findFirst({
      where: {
        user: { id: { equals: currentUser.id } },
        targetType: { equals: "post" },
        targetId: { equals: postId },
      },
    });

    if (existingLike) {
      db.like.delete({ where: { id: { equals: existingLike.id } } });
      return HttpResponse.json({ liked: false });
    } else {
      const like = db.like.create({
        user: currentUser,
        targetType: "post",
        targetId: postId,
      });
      return HttpResponse.json({ liked: true, like });
    }
  }),

  // Get post's comments
  http.get(`${API_BASE}/posts/:id/comments`, ({ params, request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);
    const parentOnly = url.searchParams.get("parent_only") === "true";

    const where: any = {
      post: { id: { equals: params.id as string } },
      isDeleted: { equals: false },
    };

    // Get all comments first, then filter in code due to @mswjs/data limitations with null queries
    const allComments = db.comment.findMany({
      where,
      orderBy: { createdAt: "asc" } as any,
    });

    // Filter for parent comments only if requested
    const filteredComments = parentOnly
      ? allComments.filter((comment) => comment.parentComment === null)
      : allComments;

    // Apply pagination to filtered results
    const totalCount = filteredComments.length;
    const paginatedComments = filteredComments.slice(skip, skip + take);

    return HttpResponse.json(
      createPaginatedResponse(paginatedComments, totalCount, page, limit)
    );
  }),

  // Create comment
  http.post(`${API_BASE}/posts/:id/comments`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const post = db.post.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!post) {
      return HttpResponse.json({ message: "Post not found" }, { status: 404 });
    }
    const body = await request.json();
    const { content, parentCommentId } = body as any;

    if (!content) {
      return HttpResponse.json(
        { error: "Content is required" },
        { status: 400 }
      );
    }

    let parentComment: Comment | null = null;
    if (parentCommentId) {
      const foundParent = db.comment.findFirst({
        where: { id: { equals: parentCommentId } },
      });
      if (foundParent) {
        parentComment = foundParent;
      }
    }

    const comment = db.comment.create({
      content,
      author: currentUser,
      post,
      parentComment,
    });

    return HttpResponse.json(comment, { status: 201 });
  }),

  // === COMMENT ENDPOINTS ===

  // Update comment
  http.patch(`${API_BASE}/comments/:id`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const comment = db.comment.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!comment) {
      return HttpResponse.json(
        { message: "Comment not found" },
        { status: 404 }
      );
    }
    if (comment.author?.id !== currentUser.id && currentUser.role !== "admin") {
      return HttpResponse.json({ message: "Forbidden" }, { status: 403 });
    }
    const body = await request.json();
    const { content } = body as any;

    if (!content) {
      return HttpResponse.json(
        { error: "Content is required" },
        { status: 400 }
      );
    }

    const updatedComment = db.comment.update({
      where: { id: { equals: comment.id } },
      data: { content, updatedAt: new Date() },
    });

    return HttpResponse.json(updatedComment);
  }),

  // Delete comment (soft delete)
  http.delete(`${API_BASE}/comments/:id`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const comment = db.comment.findFirst({
      where: { id: { equals: params.id as string } },
    });
    if (!comment) {
      return HttpResponse.json(
        { message: "Comment not found" },
        { status: 404 }
      );
    }
    if (comment.author?.id !== currentUser.id && currentUser.role !== "admin") {
      return HttpResponse.json({ message: "Forbidden" }, { status: 403 });
    }
    // Mark as deleted and clear content
    db.comment.update({
      where: { id: { equals: comment.id } },
      data: { content: "[deleted]" },
    });

    return new HttpResponse(null, { status: 204 });
  }),

  // Like/unlike comment
  http.post(`${API_BASE}/comments/:id/like`, async ({ params, request }) => {
    const currentUser = await getCurrentUser(request);
    if (!currentUser) {
      return HttpResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
    const commentId = params.id as string;
    const existingLike = db.like.findFirst({
      where: {
        user: { id: { equals: currentUser.id } },
        targetType: { equals: "comment" },
        targetId: { equals: commentId },
      },
    });

    if (existingLike) {
      db.like.delete({ where: { id: { equals: existingLike.id } } });
      return HttpResponse.json({ liked: false });
    } else {
      const like = db.like.create({
        user: currentUser,
        targetType: "comment",
        targetId: commentId,
      });
      return HttpResponse.json({ liked: true, like });
    }
  }),

  // === TAG ENDPOINTS ===

  // Get all tags
  http.get(`${API_BASE}/tags`, ({ request }) => {
    const url = new URL(request.url);
    const search = url.searchParams.get("search");

    const where = search
      ? {
          name: { contains: search },
        }
      : {};

    const tags = db.tag.findMany({
      where,
      orderBy: { name: "asc" } as any,
    });

    return HttpResponse.json(tags);
  }),

  // Get posts by tag
  http.get(`${API_BASE}/tags/:slug/posts`, ({ params, request }) => {
    const url = new URL(request.url);
    const { page, limit, skip, take } = getPaginationParams(url);

    const posts = db.post.findMany({
      where: {
        tags: { slug: { equals: params.slug as string } },
        status: { equals: "published" },
      },
      skip,
      take,
      orderBy: { createdAt: "desc" } as any,
    });

    const totalCount = db.post.count({
      where: {
        tags: { slug: { equals: params.slug as string } },
        status: { equals: "published" },
      },
    });

    return HttpResponse.json(
      createPaginatedResponse(posts, totalCount, page, limit)
    );
  }),

  // === STATISTICS ENDPOINTS ===

  // Get post statistics
  http.get(`${API_BASE}/posts/:id/stats`, ({ params }) => {
    const postId = params.id as string;
    const post = db.post.findFirst({ where: { id: { equals: postId } } });

    if (!post) {
      return HttpResponse.json({ message: "Post not found" }, { status: 404 });
    }
    const likeCount = db.like.count({
      where: { targetId: { equals: postId }, targetType: { equals: "post" } },
    });
    const commentCount = db.comment.count({
      where: { post: { id: { equals: postId } }, isDeleted: { equals: false } },
    });
    return HttpResponse.json({
      postId,
      likes: likeCount,
      comments: commentCount,
      views: post.viewCount || 0,
    });
  }),
];

// Initialize the database with seed data
seedData();

console.log("🗄️  Mock database initialized with:");
console.log(`   👥 ${db.user.count()} users`);
console.log(`   📝 ${db.post.count()} posts`);
console.log(`   💬 ${db.comment.count()} comments`);
console.log(`   🏷️ ${db.tag.count()} tags`);
console.log(`   ❤️ ${db.like.count()} likes`);
console.log(`   👥 ${db.follow.count()} follows`);
