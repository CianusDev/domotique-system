export interface SensorTypeInterface {
  id: string;
  type: string;
  name: string;
  description?: string | null;
  dataFields: unknown; // JSON: [{field, unit, dataType}]
  category: string;
  isActive: boolean;
  createdAt: Date;
}
