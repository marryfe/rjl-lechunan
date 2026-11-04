
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "add_ons": {
                  Row: {
                    "id": string,"inventory_item_id": string | null,"is_active": boolean,"name": string,"price": number,"product_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"inventory_item_id"?: string | null,"is_active"?: boolean,"name": string,"price"?: number,"product_id": string
                  }
                  Update: {
                    "id"?: string,"inventory_item_id"?: string | null,"is_active"?: boolean,"name"?: string,"price"?: number,"product_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "add_ons_inventory_item_id_fkey"
      columns: ["inventory_item_id"]
isOneToOne: false
      referencedRelation: "inventory_items"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "add_ons_product_id_fkey"
      columns: ["product_id"]
isOneToOne: false
      referencedRelation: "products"
      referencedColumns: ["id"]
    }
                  ]
                },"categories": {
                  Row: {
                    "id": string,"name": string,"sort_order": number
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"name": string,"sort_order"?: number
                  }
                  Update: {
                    "id"?: string,"name"?: string,"sort_order"?: number
                  }
                  Relationships: [
                    
                  ]
                },"daily_capacity": {
                  Row: {
                    "date": string,"is_closed": boolean,"max_kg": number,"max_pigs": number,"note": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "date": string,"is_closed"?: boolean,"max_kg": number,"max_pigs": number,"note"?: string | null
                  }
                  Update: {
                    "date"?: string,"is_closed"?: boolean,"max_kg"?: number,"max_pigs"?: number,"note"?: string | null
                  }
                  Relationships: [
                    
                  ]
                },"freebie_rule_items": {
                  Row: {
                    "id": string,"inventory_item_id": string,"qty": number,"rule_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"inventory_item_id": string,"qty": number,"rule_id": string
                  }
                  Update: {
                    "id"?: string,"inventory_item_id"?: string,"qty"?: number,"rule_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "freebie_rule_items_inventory_item_id_fkey"
      columns: ["inventory_item_id"]
isOneToOne: false
      referencedRelation: "inventory_items"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "freebie_rule_items_rule_id_fkey"
      columns: ["rule_id"]
isOneToOne: false
      referencedRelation: "freebie_rules"
      referencedColumns: ["id"]
    }
                  ]
                },"freebie_rules": {
                  Row: {
                    "created_at": string,"end_date": string | null,"id": string,"is_active": boolean,"name": string,"priority": number,"size_id": string | null,"start_date": string | null,"threshold": number | null,"trigger": Database["public"]['Enums']["freebie_trigger"]
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"end_date"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"priority"?: number,"size_id"?: string | null,"start_date"?: string | null,"threshold"?: number | null,"trigger": Database["public"]['Enums']["freebie_trigger"]
                  }
                  Update: {
                    "created_at"?: string,"end_date"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"priority"?: number,"size_id"?: string | null,"start_date"?: string | null,"threshold"?: number | null,"trigger"?: Database["public"]['Enums']["freebie_trigger"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "freebie_rules_size_id_fkey"
      columns: ["size_id"]
isOneToOne: false
      referencedRelation: "product_sizes"
      referencedColumns: ["id"]
    }
                  ]
                },"inventory_items": {
                  Row: {
                    "created_at": string,"id": string,"is_active": boolean,"kind": Database["public"]['Enums']["inventory_kind"],"name": string,"on_hand": number,"reorder_level": number,"reserved": number,"unit": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"is_active"?: boolean,"kind": Database["public"]['Enums']["inventory_kind"],"name": string,"on_hand"?: number,"reorder_level"?: number,"reserved"?: number,"unit": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"is_active"?: boolean,"kind"?: Database["public"]['Enums']["inventory_kind"],"name"?: string,"on_hand"?: number,"reorder_level"?: number,"reserved"?: number,"unit"?: string
                  }
                  Relationships: [
                    
                  ]
                },"order_freebies": {
                  Row: {
                    "id": string,"inventory_item_id": string,"item_name": string,"order_id": string,"qty": number,"rule_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"inventory_item_id": string,"item_name": string,"order_id": string,"qty": number,"rule_id"?: string | null
                  }
                  Update: {
                    "id"?: string,"inventory_item_id"?: string,"item_name"?: string,"order_id"?: string,"qty"?: number,"rule_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "order_freebies_inventory_item_id_fkey"
      columns: ["inventory_item_id"]
isOneToOne: false
      referencedRelation: "inventory_items"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_freebies_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_freebies_rule_id_fkey"
      columns: ["rule_id"]
isOneToOne: false
      referencedRelation: "freebie_rules"
      referencedColumns: ["id"]
    }
                  ]
                },"order_items": {
                  Row: {
                    "add_ons": NonNullable<Json>,"id": string,"kg": number | null,"line_total": number,"order_id": string,"product_id": string,"product_name": string,"qty": number,"size_id": string | null,"size_name": string | null,"unit_price": number
                  }
                  ComputedFields: never
                  Insert: {
                    "add_ons"?: NonNullable<Json>,"id"?: string,"kg"?: number | null,"line_total": number,"order_id": string,"product_id": string,"product_name": string,"qty"?: number,"size_id"?: string | null,"size_name"?: string | null,"unit_price": number
                  }
                  Update: {
                    "add_ons"?: NonNullable<Json>,"id"?: string,"kg"?: number | null,"line_total"?: number,"order_id"?: string,"product_id"?: string,"product_name"?: string,"qty"?: number,"size_id"?: string | null,"size_name"?: string | null,"unit_price"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "order_items_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_items_product_id_fkey"
      columns: ["product_id"]
isOneToOne: false
      referencedRelation: "products"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_items_size_id_fkey"
      columns: ["size_id"]
isOneToOne: false
      referencedRelation: "product_sizes"
      referencedColumns: ["id"]
    }
                  ]
                },"order_messages": {
                  Row: {
                    "body": string,"created_at": string,"id": string,"order_id": string,"sender": Database["public"]['Enums']["message_sender"],"staff_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "body": string,"created_at"?: string,"id"?: string,"order_id": string,"sender": Database["public"]['Enums']["message_sender"],"staff_id"?: string | null
                  }
                  Update: {
                    "body"?: string,"created_at"?: string,"id"?: string,"order_id"?: string,"sender"?: Database["public"]['Enums']["message_sender"],"staff_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "order_messages_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_messages_staff_id_fkey"
      columns: ["staff_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"order_status_history": {
                  Row: {
                    "created_at": string,"from_status": Database["public"]['Enums']["order_status"] | null,"id": string,"note": string | null,"order_id": string,"to_status": Database["public"]['Enums']["order_status"],"user_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"from_status"?: Database["public"]['Enums']["order_status"] | null,"id"?: string,"note"?: string | null,"order_id": string,"to_status": Database["public"]['Enums']["order_status"],"user_id"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"from_status"?: Database["public"]['Enums']["order_status"] | null,"id"?: string,"note"?: string | null,"order_id"?: string,"to_status"?: Database["public"]['Enums']["order_status"],"user_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "order_status_history_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "order_status_history_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"orders": {
                  Row: {
                    "address": string | null,"amount_paid": number,"balance_due": number | null,"cancel_reason": string | null,"created_at": string,"customer_email": string | null,"customer_mobile": string,"customer_name": string,"delivery_fee": number,"downpayment_due_at": string | null,"fulfillment": Database["public"]['Enums']["fulfillment_type"],"id": string,"landmark": string | null,"order_no": string,"pig_count": number,"scheduled_date": string,"status": Database["public"]['Enums']["order_status"],"stock_reserved": boolean,"subtotal": number,"time_slot": string,"total": number,"total_kg": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "address"?: string | null,"amount_paid"?: number,"balance_due"?: never,"cancel_reason"?: string | null,"created_at"?: string,"customer_email"?: string | null,"customer_mobile": string,"customer_name": string,"delivery_fee"?: number,"downpayment_due_at"?: string | null,"fulfillment": Database["public"]['Enums']["fulfillment_type"],"id"?: string,"landmark"?: string | null,"order_no"?: string,"pig_count"?: number,"scheduled_date": string,"status"?: Database["public"]['Enums']["order_status"],"stock_reserved"?: boolean,"subtotal": number,"time_slot": string,"total": number,"total_kg"?: number,"updated_at"?: string
                  }
                  Update: {
                    "address"?: string | null,"amount_paid"?: number,"balance_due"?: never,"cancel_reason"?: string | null,"created_at"?: string,"customer_email"?: string | null,"customer_mobile"?: string,"customer_name"?: string,"delivery_fee"?: number,"downpayment_due_at"?: string | null,"fulfillment"?: Database["public"]['Enums']["fulfillment_type"],"id"?: string,"landmark"?: string | null,"order_no"?: string,"pig_count"?: number,"scheduled_date"?: string,"status"?: Database["public"]['Enums']["order_status"],"stock_reserved"?: boolean,"subtotal"?: number,"time_slot"?: string,"total"?: number,"total_kg"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"payments": {
                  Row: {
                    "amount": number,"id": string,"method": Database["public"]['Enums']["payment_method"],"note": string | null,"order_id": string,"paid_at": string,"received_by": string,"reference_no": string | null,"type": Database["public"]['Enums']["payment_type"]
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"id"?: string,"method": Database["public"]['Enums']["payment_method"],"note"?: string | null,"order_id": string,"paid_at"?: string,"received_by": string,"reference_no"?: string | null,"type": Database["public"]['Enums']["payment_type"]
                  }
                  Update: {
                    "amount"?: number,"id"?: string,"method"?: Database["public"]['Enums']["payment_method"],"note"?: string | null,"order_id"?: string,"paid_at"?: string,"received_by"?: string,"reference_no"?: string | null,"type"?: Database["public"]['Enums']["payment_type"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "payments_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "payments_received_by_fkey"
      columns: ["received_by"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                },"product_sizes": {
                  Row: {
                    "approx_weight_kg": number | null,"id": string,"inventory_item_id": string | null,"is_active": boolean,"name": string,"price": number,"product_id": string,"serves": string | null,"sort_order": number
                  }
                  ComputedFields: never
                  Insert: {
                    "approx_weight_kg"?: number | null,"id"?: string,"inventory_item_id"?: string | null,"is_active"?: boolean,"name": string,"price": number,"product_id": string,"serves"?: string | null,"sort_order"?: number
                  }
                  Update: {
                    "approx_weight_kg"?: number | null,"id"?: string,"inventory_item_id"?: string | null,"is_active"?: boolean,"name"?: string,"price"?: number,"product_id"?: string,"serves"?: string | null,"sort_order"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "product_sizes_inventory_item_id_fkey"
      columns: ["inventory_item_id"]
isOneToOne: false
      referencedRelation: "inventory_items"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "product_sizes_product_id_fkey"
      columns: ["product_id"]
isOneToOne: false
      referencedRelation: "products"
      referencedColumns: ["id"]
    }
                  ]
                },"products": {
                  Row: {
                    "category_id": string | null,"created_at": string,"description": string | null,"id": string,"is_active": boolean,"kg_step": number,"min_kg": number,"name": string,"photo_path": string | null,"price_per_kg": number | null,"sell_type": Database["public"]['Enums']["sell_type"],"sort_order": number
                  }
                  ComputedFields: never
                  Insert: {
                    "category_id"?: string | null,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"kg_step"?: number,"min_kg"?: number,"name": string,"photo_path"?: string | null,"price_per_kg"?: number | null,"sell_type": Database["public"]['Enums']["sell_type"],"sort_order"?: number
                  }
                  Update: {
                    "category_id"?: string | null,"created_at"?: string,"description"?: string | null,"id"?: string,"is_active"?: boolean,"kg_step"?: number,"min_kg"?: number,"name"?: string,"photo_path"?: string | null,"price_per_kg"?: number | null,"sell_type"?: Database["public"]['Enums']["sell_type"],"sort_order"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "products_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["id"]
    }
                  ]
                },"profiles": {
                  Row: {
                    "created_at": string,"full_name": string,"id": string,"is_active": boolean,"push_token": string | null,"role": Database["public"]['Enums']["user_role"]
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"full_name": string,"id": string,"is_active"?: boolean,"push_token"?: string | null,"role"?: Database["public"]['Enums']["user_role"]
                  }
                  Update: {
                    "created_at"?: string,"full_name"?: string,"id"?: string,"is_active"?: boolean,"push_token"?: string | null,"role"?: Database["public"]['Enums']["user_role"]
                  }
                  Relationships: [
                    
                  ]
                },"settings": {
                  Row: {
                    "booking_window_days": number,"contact_mobile": string | null,"default_max_kg_per_day": number,"default_max_pigs_per_day": number,"delivery_enabled": boolean,"delivery_fee": number,"downpayment_deadline_hours": number,"freebies_stack": boolean,"id": number,"messenger_url": string | null,"order_lead_days": number,"pickup_address": string | null,"store_name": string,"time_slots": (string)[],"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "booking_window_days"?: number,"contact_mobile"?: string | null,"default_max_kg_per_day"?: number,"default_max_pigs_per_day"?: number,"delivery_enabled"?: boolean,"delivery_fee"?: number,"downpayment_deadline_hours"?: number,"freebies_stack"?: boolean,"id"?: number,"messenger_url"?: string | null,"order_lead_days"?: number,"pickup_address"?: string | null,"store_name"?: string,"time_slots"?: (string)[],"updated_at"?: string
                  }
                  Update: {
                    "booking_window_days"?: number,"contact_mobile"?: string | null,"default_max_kg_per_day"?: number,"default_max_pigs_per_day"?: number,"delivery_enabled"?: boolean,"delivery_fee"?: number,"downpayment_deadline_hours"?: number,"freebies_stack"?: boolean,"id"?: number,"messenger_url"?: string | null,"order_lead_days"?: number,"pickup_address"?: string | null,"store_name"?: string,"time_slots"?: (string)[],"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"stock_movements": {
                  Row: {
                    "created_at": string,"id": string,"item_id": string,"note": string | null,"on_hand_change": number,"order_id": string | null,"reason": Database["public"]['Enums']["movement_reason"],"reserved_change": number,"user_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"item_id": string,"note"?: string | null,"on_hand_change"?: number,"order_id"?: string | null,"reason": Database["public"]['Enums']["movement_reason"],"reserved_change"?: number,"user_id"?: string | null
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"item_id"?: string,"note"?: string | null,"on_hand_change"?: number,"order_id"?: string | null,"reason"?: Database["public"]['Enums']["movement_reason"],"reserved_change"?: number,"user_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "stock_movements_item_id_fkey"
      columns: ["item_id"]
isOneToOne: false
      referencedRelation: "inventory_items"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "stock_movements_order_id_fkey"
      columns: ["order_id"]
isOneToOne: false
      referencedRelation: "orders"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "stock_movements_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "profiles"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "adjust_stock":
{ Args: { "p_change": number,"p_item_id": string,"p_note"?: string,"p_reason": Database["public"]['Enums']["movement_reason"] }; Returns: undefined
                           },
"completed_sales":
{ Args: Record<PropertyKey, never>; Returns: {
              "day": string,"order_id": string,"total": number
            }[]
                           },
"get_availability":
{ Args: { "p_from": string,"p_to": string }; Returns: {
              "day": string,"is_open": boolean,"kg_left": number,"pigs_left": number,"reason": string
            }[]
                           },
"get_dashboard":
{ Args: { "p_date": string }; Returns: Json
                           },
"get_prep_sheet":
{ Args: { "p_date": string }; Returns: Json
                           },
"get_public_order":
{ Args: { "p_mobile": string,"p_order_no": string }; Returns: Json
                           },
"is_admin":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"is_staff":
{ Args: Record<PropertyKey, never>; Returns: boolean
                           },
"manila_today":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"normalize_mobile":
{ Args: { "p_mobile": string }; Returns: string
                           },
"place_order":
{ Args: { "p_order": Json }; Returns: Json
                           },
"post_customer_message":
{ Args: { "p_body": string,"p_mobile": string,"p_order_no": string }; Returns: undefined
                           },
"post_staff_message":
{ Args: { "p_body": string,"p_order_id": string }; Returns: undefined
                           },
"quote_cart":
{ Args: { "p_date"?: string,"p_fulfillment": Database["public"]['Enums']["fulfillment_type"],"p_items": Json }; Returns: Json
                           },
"record_payment":
{ Args: { "p_amount": number,"p_method": Database["public"]['Enums']["payment_method"],"p_note"?: string,"p_order_id": string,"p_reference"?: string,"p_type": Database["public"]['Enums']["payment_type"] }; Returns: undefined
                           },
"report_sales":
{ Args: { "p_from": string,"p_to": string }; Returns: Json
                           },
"reserve_order_stock":
{ Args: { "p_order_id": string }; Returns: undefined
                           },
"set_order_status":
{ Args: { "p_note"?: string,"p_order_id": string,"p_to": Database["public"]['Enums']["order_status"] }; Returns: undefined
                           },
"set_staff":
{ Args: { "p_full_name": string,"p_is_active": boolean,"p_role": Database["public"]['Enums']["user_role"],"p_user_id": string }; Returns: undefined
                           },
"set_stock_count":
{ Args: { "p_counted": number,"p_item_id": string,"p_note"?: string }; Returns: undefined
                           },
"settle_order_stock":
{ Args: { "p_order_id": string,"p_reason": Database["public"]['Enums']["movement_reason"] }; Returns: undefined
                           },
"try_date":
{ Args: { "p_value": string }; Returns: string
                           },
"try_numeric":
{ Args: { "p_value": string }; Returns: number
                           },
"try_uuid":
{ Args: { "p_value": string }; Returns: string
                           }
          }
          Enums: {
            "freebie_trigger": "size"|"kg_threshold"|"order_amount"|"promo_dates","fulfillment_type": "pickup"|"delivery","inventory_kind": "pig"|"supply"|"freebie","message_sender": "customer"|"staff","movement_reason": "purchase"|"reserve"|"release"|"deduct"|"spoilage"|"adjustment"|"count","order_status": "new"|"awaiting_downpayment"|"confirmed"|"roasting"|"ready"|"out_for_delivery"|"completed"|"cancelled","payment_method": "cash"|"gcash"|"bank_transfer"|"other","payment_type": "downpayment"|"cod_balance"|"refund","sell_type": "by_kg"|"by_size","user_role": "admin"|"staff"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            "freebie_trigger": ["size", "kg_threshold", "order_amount", "promo_dates"],"fulfillment_type": ["pickup", "delivery"],"inventory_kind": ["pig", "supply", "freebie"],"message_sender": ["customer", "staff"],"movement_reason": ["purchase", "reserve", "release", "deduct", "spoilage", "adjustment", "count"],"order_status": ["new", "awaiting_downpayment", "confirmed", "roasting", "ready", "out_for_delivery", "completed", "cancelled"],"payment_method": ["cash", "gcash", "bank_transfer", "other"],"payment_type": ["downpayment", "cod_balance", "refund"],"sell_type": ["by_kg", "by_size"],"user_role": ["admin", "staff"]
          }
        }
} as const
