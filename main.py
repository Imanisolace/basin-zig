from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import traceback
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

# INIT PADDLE
PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")
PADDLE_API_URL = "https://sandbox-api.paddle.com"
print("PADDLE KEY LOADED:", "YES" if PADDLE_API_KEY else "NO")
print("KEY STARTS WITH:", PADDLE_API_KEY[:10] if PADDLE_API_KEY else "NONE")

headers = {
    "Authorization": f"Bearer {PADDLE_API_KEY}",
    "Content-Type": "application/json"
}

class CheckoutRequest(BaseModel):
    priceId: str
    email: str
    user_id: str

class UserRequest(BaseModel):
    user_id: str
    email: str

@app.post("/create-checkout")
def create_checkout(req: CheckoutRequest):
    if not PADDLE_API_KEY:
        return {"error": "PADDLE_API_KEY not set on server"}
    if not PADDLE_API_KEY.startswith("pdl_sbox_"):
        return {"error": "You are using a LIVE key. Use SANDBOX key starting with pdl_sbox_"}

    try:
        print(f"REQUEST RECEIVED: {req.priceId} for {req.email}")
        
        payload = {
            "items": [{"price_id": req.priceId, "quantity": 1}],
            "customer": {"email": req.email},
            "custom_data": {"user_id": req.user_id}
        }
        print("PAYLOAD TO PADDLE:", payload)
            
        r = requests.post(f"{PADDLE_API_URL}/checkouts", json=payload, headers=headers, timeout=30)
        
        print("PADDLE STATUS:", r.status_code)
        print("PADDLE RESPONSE:", r.text)
        
        if r.status_code != 200:
            return {"error": f"Paddle Error {r.status_code}: {r.text}"}
            
        checkout = r.json()["data"]
        return {"url": checkout["url"]}
        
    except Exception as e:
        print("GENERAL ERROR:")
        print(traceback.format_exc())
        return {"error": str(e)}

@app.post("/apikey")
def get_apikey(data: UserRequest):
    return {
        "apiKey": "zk_abafe6601f4bfef74bb54f3b4b43853b",
        "tier": "free",
        "billing": None,
        "limits": {"prove": 1000, "verify": 5000}
    }

@app.post("/prove")
def prove(data: UserRequest):
    return {"status": "proved", "user_id": data.user_id, "email": data.email, "proof": "zk_proof_placeholder"}

@app.get("/")
def health():
    return {"status": "Basin ZK API is running"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)