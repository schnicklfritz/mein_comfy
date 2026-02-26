# --- Blackwell (sm_120) Hardware Alignment ---
echo "🚀 Aligning environment for Blackwell Architecture..."

# 1. Force-install Blackwell-compatible Triton/SageAttention
# Standard pip wheels often lack sm_120 support; source build is required
pip install --upgrade setuptools wheel
pip install sageattention --no-binary sageattention

# 2. Ensure FlashAttention/SageAttention can compile
# OpenSUSE uses zypper; installing ninja if not already present in Dockerfile
if ! command -v ninja &> /dev/null; then
    zypper --non-interactive install ninja
fi

# 3. Environment Variable Injection for Blackwell Performance
# These align with your --bf16-unet and --use-sage-attention flags
export TORCH_CUDA_ARCH_LIST="12.0"
export VLLM_ATTENTION_BACKEND=FLASHINFER
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

echo "✅ Blackwell alignment complete."
