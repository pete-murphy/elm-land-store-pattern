export function set(credentials: Record<string, unknown> | null) {
  if (credentials === null) {
    localStorage.removeItem("credentials");
  } else {
    localStorage.setItem("credentials", JSON.stringify(credentials));
  }
}

export function get(): Record<string, unknown> | null {
  const credentials = localStorage.getItem("credentials");
  return credentials ? JSON.parse(credentials) : null;
}

export function update(newCredentials: Record<string, unknown>) {
  const credentials = get();
  if (credentials === null) {
    throw new Error("No credentials found");
  }
  set({ ...credentials, ...newCredentials });
}
