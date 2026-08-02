from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import uvicorn
import requests

app = FastAPI(title="Basin ZK API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")
PADDLE_API_URL = "https://sandbox-api.paddle.com"
print("PADDLE KEY LOADED:", "YES" if PADDLE_API_KEY else "NO")

headers = {
    "Authorization": f"Bearer {PADDLE_API_KEY}",
    "Content-Type": "application/json"
}

class CheckoutRequest(BaseModel):
    priceId: str
    email: str
    user_id: str

@app.post("/create-checkout")
def create_checkout(req: CheckoutRequest):
    try:
        # NEW PADDLE API: /transactions instead of /checkouts
        payload = {
            "items": [{"price_id": req.priceId, "quantity": 1}],
            "customer_email": req.email, # Note: customer_email not customer.email
            "custom_data": {"user_id": req.user_id}
        }
        print("PAYLOAD TO PADDLE:", payload)
            
        r = requests.post(f"{PADDLE_API_URL}/transactions", json=payload, headers=headers, timeout=30)
        
        print("PADDLE STATUS:", r.status_code)
        print("PADDLE RESPONSE:", r.text)
        
        if r.status_code != 201:
            return {"error": f"Paddle Error {r.status_code}: {r.text}"}
            
        transaction = r.json()["data"]
        # Get the hosted checkout url
        return {"url": transaction["checkout"]["url"]}
        
    except Exception as e:
        return {"error": str(e)}

@app.post("/apikey")
def get_apikey(data: dict):
    return {"apiKey": "zk_abafe6601f4bfef74bb54f3b4b43853b", "tier": "free", "billing": None, "limits": {"prove": 1000, "verify": 5000}}

@app.post("/prove")
def prove(data: dict):
    return {"status": "proved", "user_id": data.get("user_id"), "email": data.get("email"), "proof": "zk_proof_placeholder"}

@app.get("/")
def health():
    return {"status": "Basin ZK API is running"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)