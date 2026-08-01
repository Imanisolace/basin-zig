from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from paddle_billing import Client, Environment
import os
import traceback

app = FastAPI(title="Basin ZK API")

# Allow your html.to frontend to call the backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change to "https://html.to" later for security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# INIT PADDLE SANDBOX CLIENT
PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")

if not PADDLE_API_KEY:
    print("ERROR: PADDLE_API_KEY env var is missing!")

paddle = Client(PADDLE_API_KEY, environment=Environment.SANDBOX)


# MODELS
class CheckoutRequest(BaseModel):
    priceId: str
    email: str
    user_id: str
    return_url: str

class UserRequest(BaseModel):
    user_id: str
    email: str


# 1. CREATE PADDLE CHECKOUT SESSION
@app.post("/create-checkout")
def create_checkout(req: CheckoutRequest):
    """
    Creates a Paddle checkout session and returns the hosted URL
    """
    try:
        print(f"Creating checkout for: {req.priceId} | {req.email}")
        checkout = paddle.checkouts.create(
            items=[{"price_id": req.priceId, "quantity": 1}],
            customer={"email": req.email},
            custom_data={"user_id": req.user_id},
            return_url=req.return_url
        )
        print(f"Checkout URL created: {checkout.url}")
        return {"url": checkout.url}
    except Exception as e:
        print("ERROR IN CREATE-CHECKOUT:")
        print(traceback.format_exc())
        return {"error": str(e)}


# 2. GET API KEY
@app.post("/apikey")
def get_apikey(data: UserRequest):
    print(f"apikey called for {data.user_id}")
    api_key = f"zk_abafe6601f4bfef74bb54f3b4b43853b"
    
    return {
        "apiKey": api_key,
        "tier": "free",
        "billing": None,
        "limits": {
            "prove": 1000,
            "verify": 5000
        }
    }


# 3. PROVE
@app.post("/prove")
def prove(data: UserRequest):
    print(f"prove called for {data.user_id}")
    return {
        "status": "proved",
        "user_id": data.user_id,
        "email": data.email,
        "proof": "zk_proof_placeholder"
    }


# 4. HEALTH CHECK
@app.get("/")
def health():
    return {"status": "Basin ZK API is running"}