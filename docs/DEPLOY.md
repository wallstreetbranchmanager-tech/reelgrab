# Deploy ReelGrab

## Local (dev)

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
# need ffmpeg installed on system
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open frontend/index.html in browser (or serve it). Change API URL if needed.

## Production notes

- Put backend behind auth + rate limits.
- Use residential proxies or Playwright stealth for extract (still against ToS).
- For real continuous camera (orbit/dolly/first-person like MeltFlex claims): pipe stills into a paid image-to-video model (Veo, Runway Gen-3, Luma Dream Machine, Kling, etc.) then stitch. Costs money per second.
- Ken Burns is free, fast, reliable, and good enough for most agent social/MLS use.
- Stripe: free tier 1 video, then $19/mo for 20 videos, $39/mo unlimited + branding + no watermark + batch.
- Add virtual staging by calling Grok Imagine / Flux / SD3 on each room photo before video step.
- Legal: force users to check "I own the rights or am the listing agent" checkbox. Log it. Still not bulletproof.

This is the same core loop the $20-50/mo competitors run. Difference is packaging, speed, polish, and how hard they hide the ToS risk.
