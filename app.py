import os
import cv2
import numpy as np
import torch
import torch.nn as nn
import gradio as gr

# -------------------------------------------------------------
# Model Architecture (U-Net)
# -------------------------------------------------------------
class DoubleConv(nn.Module):
    def __init__(self, in_channels, out_channels):
        super().__init__()
        self.conv = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, 3, padding=1),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_channels, out_channels, 3, padding=1),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
        )

    def forward(self, x):
        return self.conv(x)


class UNet(nn.Module):
    def __init__(self, n_classes=1):
        super().__init__()
        self.d1 = DoubleConv(3, 64)
        self.d2 = DoubleConv(64, 128)
        self.d3 = DoubleConv(128, 256)
        self.d4 = DoubleConv(256, 512)
        self.pool = nn.MaxPool2d(2)
        self.up3 = nn.ConvTranspose2d(512, 256, 2, 2)
        self.u3 = DoubleConv(512, 256)
        self.up2 = nn.ConvTranspose2d(256, 128, 2, 2)
        self.u2 = DoubleConv(256, 128)
        self.up1 = nn.ConvTranspose2d(128, 64, 2, 2)
        self.u1 = DoubleConv(128, 64)
        self.final = nn.Conv2d(64, n_classes, 1)

    def forward(self, x):
        c1 = self.d1(x)
        c2 = self.d2(self.pool(c1))
        c3 = self.d3(self.pool(c2))
        c4 = self.d4(self.pool(c3))

        u3 = self.up3(c4)
        u3 = torch.cat([u3, c3], dim=1)
        u3 = self.u3(u3)

        u2 = self.up2(u3)
        u2 = torch.cat([u2, c2], dim=1)
        u2 = self.u2(u2)

        u1 = self.up1(u2)
        u1 = torch.cat([u1, c1], dim=1)
        u1 = self.u1(u1)

        return torch.sigmoid(self.final(u1))


# -------------------------------------------------------------
# Model Initialization
# -------------------------------------------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"[*] Inference device: {device}")

def load_model():
    model = UNet()
    weights_path = os.environ.get("MODEL_PATH", "road_unet_epoch15.pth")
    if not os.path.exists(weights_path):
        if os.path.exists("road_unet_epoch5.pth"):
            weights_path = "road_unet_epoch5.pth"
        else:
            raise FileNotFoundError(f"Model weights not found at {weights_path}")

    print(f"[*] Loading model weights from: {weights_path}")
    state_dict = torch.load(weights_path, map_location=device)
    model.load_state_dict(state_dict)
    model.to(device)
    model.eval()
    print("[*] Model loaded successfully and ready for inference!")
    return model

model = load_model()


# -------------------------------------------------------------
# Prediction Pipeline
# -------------------------------------------------------------
def predict_road_mask(image, threshold=0.5):
    """
    Predict binary road mask and road overlay for input satellite image.
    """
    if image is None:
        return None, None

    orig_h, orig_w = image.shape[:2]

    # Resize to model input resolution
    img_resized = cv2.resize(image, (512, 512))
    inp = torch.tensor(img_resized).permute(2, 0, 1).float().unsqueeze(0) / 255.0
    inp = inp.to(device)

    # Predict mask
    with torch.no_grad():
        pred = model(inp)
    mask = (pred > threshold).float().cpu().numpy()[0, 0]

    # Generate road overlay (roads highlighted in green)
    mask_uint8 = (mask * 255).astype(np.uint8)
    mask_rgb = np.zeros_like(img_resized)
    mask_rgb[..., 1] = mask_uint8  # Green channel
    overlay = cv2.addWeighted(img_resized, 0.75, mask_rgb, 0.65, 0)

    # Resize back to original dimensions for high-resolution output
    mask_full = cv2.resize(mask_uint8, (orig_w, orig_h), interpolation=cv2.INTER_NEAREST)
    overlay_full = cv2.resize(overlay, (orig_w, orig_h))

    return mask_full, overlay_full


# -------------------------------------------------------------
# Gradio Web Interface
# -------------------------------------------------------------
examples = []
if os.path.exists("unseen.png"):
    examples.append(["unseen.png", 0.5])

title = "🛰️ Satellite Road Extraction & Accessibility Detector"
description = """
**Deep Learning Road Extraction using PyTorch U-Net**
Upload a satellite image (or select the sample example below) to segment navigable roads and accessibility corridors.
- **Predicted Road Mask:** High-contrast binary road segmentation mask.
- **Satellite Overlay:** Overlay showing predicted road networks highlighted in green.
"""

demo = gr.Interface(
    fn=predict_road_mask,
    inputs=[
        gr.Image(label="Upload Satellite Image", type="numpy"),
        gr.Slider(minimum=0.1, maximum=0.9, value=0.5, step=0.05, label="Detection Confidence Threshold"),
    ],
    outputs=[
        gr.Image(label="Predicted Road Mask", type="numpy"),
        gr.Image(label="Road Overlay on Satellite Image", type="numpy"),
    ],
    title=title,
    description=description,
    examples=examples if examples else None,
    allow_flagging="never",
)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 7860))
    print(f"[*] Starting Gradio server on 0.0.0.0:{port}...")
    demo.launch(server_name="0.0.0.0", server_port=port, share=False)
