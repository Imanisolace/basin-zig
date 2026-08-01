from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from paddle_billing import Client, Environment
import os

app = FastAPI()

# Allow your html.to site to call the backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # change to your html.to domain later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# INIT PADDLE SANDBOX CLIENT
PADDLE_API_KEY = os.getenv("PADDLE_API_KEY") # put your sandbox api key in Railway env vars
paddle = Client(PADDLE_API_KEY, environment=Environment.SANDBOX)

class CheckoutRequest(BaseModel):
    priceId: str
    email: str
    user_id: str
    return_url: str

@app.post("/create-checkout")
def create_checkout(req: CheckoutRequest):
    try:
        checkout = paddle.checkouts.create(
            items=[{"price_id": req.priceId, "quantity": 1}],
            customer={"email": req.email},
            custom_data={"user_id": req.user_id},
            return_url=req.return_url
        )
        return {"url": checkout.url}
    except Exception as e:
        return {"error": str(e)}

# YOUR EXISTING ENDPOINTS - KEEP THESE
@app.post("/apikey")
def get_apikey(data: dict):
    # your existing code
    return {"api_key": "test_123"}

@app.post("/prove")
def prove(data: dict):
    # your existing code  
    return {"status": "proved"}