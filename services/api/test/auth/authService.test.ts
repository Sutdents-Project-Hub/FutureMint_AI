import { describe, expect, it } from "vitest";

import { InMemoryRepository } from "../../src/adapters/inMemoryRepository";
import { AuthService } from "../../src/auth/authService";

const createService = () => new AuthService(new InMemoryRepository());

describe("AuthService", () => {
  it("creates a session without exposing password fields", async () => {
    const service = createService();

    const result = await service.register({
      email: "Student@Example.com",
      password: "futuremint2026",
    });

    expect(result.account).toMatchObject({
      email: "student@example.com",
      profileComplete: false,
    });
    expect(result.account).not.toHaveProperty("passwordHash");
    expect(result.account).not.toHaveProperty("passwordSalt");
    await expect(service.authenticate(result.token)).resolves.toMatchObject({
      email: "student@example.com",
      profileComplete: false,
    });
  });

  it("rejects a session after logout", async () => {
    const service = createService();
    const { token } = await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });

    await service.logout(token);

    await expect(service.authenticate(token)).rejects.toMatchObject({
      code: "unauthorized",
      status: 401,
    });
  });

  it("uses one generic error for an unknown email and a wrong password", async () => {
    const service = createService();
    await service.register({
      email: "student@example.com",
      password: "futuremint2026",
    });

    const unknown = service.login({
      email: "missing@example.com",
      password: "futuremint2026",
    });
    const wrongPassword = service.login({
      email: "student@example.com",
      password: "not-the-password2026",
    });

    await expect(unknown).rejects.toMatchObject({ code: "invalid_credentials" });
    await expect(wrongPassword).rejects.toMatchObject({
      code: "invalid_credentials",
    });
  });
});
