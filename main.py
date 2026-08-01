from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from paddle_billing import Client, Environment
from paddle_billing.exceptions import PaddleAPIError
import os
import traceback
import uvicorn

app = FastAPI(title="Basin ZK API")

# CORS - allow your html.to site
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change to "https://htmledit.squarefree.com" later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# INIT PADDLE SANDBOX CLIENT
PADDLE_API_KEY = os.getenv("PADDLE_API_KEY")
print("PADDLE KEY LOADED:", "YES" if PADDLE_API_KEY else "NO")

if PADDLE_API_KEY:
    paddle = Client(PADDLE_API_KEY, environment=Environment.SANDBOX)
else:
    paddle = None
    print("WARNING: PADDLE_API_KEY not set")

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
    if not paddle:
        return {"error": "PADDLE_API_KEY not set on server"}
    
    try:
        print(f"REQUEST RECEIVED: {req.priceId} for {req.email}")
        checkout = paddle.checkouts.create(
            items=[{"price_id": req.priceId, "quantity": 1}],
            customer={"email": req.email},
            custom_data={"user_id": req.user_id},
            return_url=req.return_url
        )
        print(f"SUCCESS: Created checkout {checkout.url}")
        return {"url": checkout.url}
    except PaddleAPIError as e:
        print("PADDLE ERROR:", e)
        return {"error": f"Paddle Error: {e.detail}"}
    except Exception as e:
        print("GENERAL ERROR:")
        print(traceback.format_exc())
        return {"error": str(e)}


# 2. GET API KEY
@app.post("/apikey")
def get_apikey(data: UserRequest):
    print(f"apikey called for {data.user_id}")
    return {
        "apiKey": "zk_abafe6601f4bfef74bb54f3b4b43853b",
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


# THIS IS THE CRITICAL PART FOR RAILWAY
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    print(f"STARTING SERVER ON PORT {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)