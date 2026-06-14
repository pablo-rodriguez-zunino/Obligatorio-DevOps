import time
import psycopg2
import psycopg2.extras
from app.models import Item, Cart
from app.service import CartService
from app.config import settings


class PostgresCartService(CartService):
    def __init__(self):
        max_retries = 10
        retry_delay = 3  
        
        for attempt in range(1, max_retries + 1):
            try:
                print(f"Intentando conectar a PostgreSQL (Intento {attempt}/{max_retries})...", flush=True)
                
                self._conn = psycopg2.connect(
                    host=settings.postgres_host,
                    port=settings.postgres_port,
                    dbname=settings.postgres_db,
                    user=settings.postgres_user,
                    password=settings.postgres_password,
                )
                self._conn.autocommit = True
                
                print("¡Conexión exitosa a PostgreSQL!", flush=True)
                break 
             
            except psycopg2.OperationalError as e:
                if attempt == max_retries:
                    print("Se agotaron los intentos de conexión. El servicio carts fallará.", flush=True)
                    raise e  
                
                print(f"Base de datos no disponible todavía ({e}). Reintentando en {retry_delay}s...", flush=True)
                time.sleep(retry_delay)

    def get(self, customer_id: str) -> Cart:
        return Cart(customerId=customer_id, items=self.get_items(customer_id))

    def delete(self, customer_id: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM cart_items WHERE customer_id = %s", (customer_id,))

    def merge(self, customer_id: str, session_id: str) -> None:
        for item in self.get_items(session_id):
            self.add_item(customer_id, item)
        self.delete(session_id)

    def get_items(self, customer_id: str) -> list[Item]:
        with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT item_id, quantity, unit_price FROM cart_items WHERE customer_id = %s",
                (customer_id,),
            )
            return [
                Item(itemId=r["item_id"], quantity=r["quantity"], unitPrice=r["unit_price"])
                for r in cur.fetchall()
            ]

    def add_item(self, customer_id: str, item: Item) -> Item:
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO cart_items (customer_id, item_id, quantity, unit_price)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (customer_id, item_id)
                DO UPDATE SET quantity = EXCLUDED.quantity, unit_price = EXCLUDED.unit_price
                """,
                (customer_id, item.itemId, item.quantity, item.unitPrice),
            )
        return item

    def update_item(self, customer_id: str, item: Item) -> Item | None:
        with self._conn.cursor() as cur:
            cur.execute(
                """
                UPDATE cart_items SET quantity = %s, unit_price = %s
                WHERE customer_id = %s AND item_id = %s
                """,
                (item.quantity, item.unitPrice, customer_id, item.itemId),
            )
            return item if cur.rowcount > 0 else None

    def get_item(self, customer_id: str, item_id: str) -> Item | None:
        with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT item_id, quantity, unit_price FROM cart_items WHERE customer_id = %s AND item_id = %s",
                (customer_id, item_id),
            )
            r = cur.fetchone()
            return Item(itemId=r["item_id"], quantity=r["quantity"], unitPrice=r["unit_price"]) if r else None

    def delete_item(self, customer_id: str, item_id: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute(
                "DELETE FROM cart_items WHERE customer_id = %s AND item_id = %s",
                (customer_id, item_id),
            )
