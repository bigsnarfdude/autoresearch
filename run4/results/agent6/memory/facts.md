# Facts

## Baseline Config
- DEPTH=8, ASPECT_RATIO=64, model_dim=512, heads=4
- TOTAL_BATCH_SIZE=2^19 (524288), DEVICE_BATCH_SIZE=32
- EMBEDDING_LR=0.6, MATRIX_LR=0.04, UNEMBEDDING_LR=0.004, SCALAR_LR=0.5
- WEIGHT_DECAY=0.2, WARMDOWN_RATIO=0.5
- Activation: ReLU squared in MLP
- HEAD_DIM=128, window pattern SSSL
- Value embeddings on alternating layers

## Results
(to be filled)
