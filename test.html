from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from paddle_billing import Client, Environment
from paddle_billing.exceptions import PaddleAPIError # NEW
import os
import traceback

app = FastAPI(title="Basin ZK API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")
print("PADDLE KEY LOADED:", "YES" if PADDLE_API_KEY else "NO") # will show in logs
paddle = Client(PADDLE_API_KEY, environment=Environment.SANDBOX)

class CheckoutRequest(BaseModel):
    priceId: str
    email: str
    user_id: str
    return_url: str

class UserRequest(BaseModel):
    user_id: str
    email: str

@app.post("/create-checkout")
def create_checkout(req: CheckoutRequest):
    try:
        print(f"Trying to create checkout for price: {req.priceId}")
        checkout = paddle.checkouts.create(
            items=[{"price_id": req.priceId, "quantity": 1}],
            customer={"email": req.email},
            custom_data={"user_id": req.user_id},
            return_url=req.return_url
        )
        return {"url": checkout.url}
    except PaddleAPIError as e: # Catches Paddle errors specifically
        print("PADDLE ERROR:", e)
        return {"error": f"Paddle Error: {e.detail}"}
    except Exception as e:
        print("GENERAL ERROR:")
        print(traceback.format_exc())
        return {"error": str(e)}

@app.post("/apikey")
def get_apikey(data: UserRequest):
    return {"apiKey": "zk_abafe6601f4bfef74bb54f3b4b43853b","tier": "free","billing": None,"limits": {"prove": 1000,"verify": 5000}}

@app.post("/prove")
def prove(data: UserRequest):
    return {"status": "proved","user_id": data.user_id,"email": data.email,"proof": "zk_proof_placeholder"}

@app.get("/")
def health():
    return {"status": "Basin ZK API is running"}