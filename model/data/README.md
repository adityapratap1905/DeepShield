# Dataset layout

Keep your dataset out of source control. Arrange labeled images like this:

```text
deepfake_faces/
  train/
    fake/
    real/
  val/
    fake/
    real/
  test/
    fake/
    real/
```

The training script consumes only `train/` and `val/`. Keep `test/` separate and use it once for final evaluation after model selection. Split by source/video/person before extracting frames so near-duplicate frames cannot leak between splits. Record dataset provenance, permissions, licenses, and limitations.
