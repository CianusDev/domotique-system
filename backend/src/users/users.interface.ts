export interface UserWithoutPassword {
  id: string;
  email: string;
  username?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  emailVerified?: boolean;
}
