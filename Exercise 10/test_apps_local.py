import unittest
import json
import product_catalog
import shopping_cart

class TestExercise10Microservices(unittest.TestCase):
    def setUp(self):
        self.catalog_client = product_catalog.app.test_client()
        self.cart_client = shopping_cart.app.test_client()
        shopping_cart.cart.clear()

    def test_product_catalog(self):
        response = self.catalog_client.get("/products")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(len(data), 3)
        self.assertEqual(data[0]["name"], "Laptop")

    def test_shopping_cart(self):
        # Empty cart initially
        res_get = self.cart_client.get("/cart")
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(json.loads(res_get.data), [])

        # Add item
        payload = {"id": 1, "name": "Laptop", "quantity": 1}
        res_post = self.cart_client.post(
            "/cart",
            data=json.dumps(payload),
            content_type="application/json"
        )
        self.assertEqual(res_post.status_code, 201)
        data = json.loads(res_post.data)
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["name"], "Laptop")

if __name__ == "__main__":
    unittest.main()
