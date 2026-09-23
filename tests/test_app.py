import unittest
from fastapi.testclient import TestClient
from src.app.main import app


class AppTests(unittest.TestCase):
    def test_health(self) -> None:
        response = TestClient(app).get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
