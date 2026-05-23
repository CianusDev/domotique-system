export interface ControllerResponse {
  success: boolean;
  message: string;
  data?: Record<string, any> | null;
}
