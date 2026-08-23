# ReelGrab v2.0 — Cinematic Listing Walkthroughs

## Quick start (NVIDIA DGX Spark, or any Docker host)
```
cd reelgrab
./install.sh
```
Then open the printed Network URL. Full deployment details: **docs/ReelGrab_DGX_Spark_Install_Guide.pdf**.


Turn a real estate agent's own listing photos into a cinematic walkthrough video:
drone-style approach on the front exterior, a true room-to-room walkthrough, and
a contact/outro card built from listing details the agent provides.

## How it works
1. **Agent uploads** the listing photos they own or are authorized to use.
2. **Auto-organize** orders them front exterior → interior → detail shots.
3. **Details** are parsed from text the agent pastes or a listing sheet/PDF they
   upload (no site is fetched; facts come from the agent's own material).
4. **Render** produces a clean walkthrough (no watermark). The first video is
   free per device (IP + browser fingerprint), then agents buy credits or upgrade to Pro.

## Endpoints
- `POST /upload` — multipart images; returns job_id + auto-ordered plan
- `POST /parse-details` — `text=` or `file=` (txt/pdf); returns structured details
- `POST /generate-video` — `job_id`, `motion`, `details_json` (always clean, no watermark)
- `GET  /free-status` — whether this device (IP + fingerprint) still has its free video
- `GET  /download/{job_id}` — the rendered mp4
- `POST /checkout`, `POST /webhook/stripe` — billing (free first video, then PPV/Pro)

## Run
```
pip install -r backend/requirements.txt
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```
Optional advanced camera (continuous motion) on a GPU box: set
`ADVANCED_CAMERA_PROVIDER=ltx` and `LTX_PATH` / `LTX_CKPT`.

## Note on rights
ReelGrab processes photos the agent uploads and details the agent supplies. It
does not scrape listing portals. Agents should only upload media they own or are
authorized to use.
