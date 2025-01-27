<script setup>
import { defineProps, defineEmits, ref, onMounted, watch } from 'vue';

const props = defineProps({
    lora: {
        type: Object,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    },
    currentPath: {  // 添加当前路径属性
        type: String,
        required: true
    }
});

const emit = defineEmits(['close']);
const currentPreviewIndex = ref(0);
const previews = ref([]);
const showUploadBox = ref(false);
const isHovering = ref(false);
const isUploading = ref(false);
const uploadProgress = ref(0);

// 重置状态的函数
function resetState() {
    currentPreviewIndex.value = 0;
    previews.value = [];
    if (props.lora.has_preview) {
        previews.value = [props.lora.preview_path];
    }
}

// 监听 lora 的变化
watch(() => props.lora, async (newLora) => {
    resetState();
    if (newLora.has_preview) {
        await loadPreviews();
    }
}, { deep: true });

// 修改 onMounted
onMounted(async () => {
    resetState();
    if (props.lora.has_preview) {
        await loadPreviews();
    }
});

async function loadPreviews() {
    try {
        const params = new URLSearchParams({
            name: props.lora.base_name,
            path: props.currentPath // 使用当前路径
        }).toString();
        
        const response = await fetch(`http://localhost:5000/previews?${params}`);
        const data = await response.json();
        if (data.previews.length > 0) {
            // 确保主预览图在第一位
            const mainPreview = props.lora.preview_path;
            const otherPreviews = data.previews.filter(p => p !== mainPreview);
            previews.value = [mainPreview, ...otherPreviews];
        }
    } catch (error) {
        console.error('获取预览图列表失败:', error);
    }
}

function handleOverlayClick(e) {
    if (e.target.classList.contains('overlay')) {
        emit('close');
    }
}

function previousPreview() {
    if (currentPreviewIndex.value > 0) {
        currentPreviewIndex.value--;
    }
}

function nextPreview() {
    if (currentPreviewIndex.value < previews.value.length - 1) {
        currentPreviewIndex.value++;
    }
}

function toggleUploadBox() {
    showUploadBox.value = !showUploadBox.value;
}

function handleButtonHover(enter) {
    isHovering.value = enter;
}

async function handleDrop(e) {
    e.preventDefault();
    const file = e.dataTransfer.files[0];
    if (!file.type.startsWith('image/')) {
        alert('请上传图片文件');
        return;
    }

    isUploading.value = true;
    uploadProgress.value = 0;
    
    const formData = new FormData();
    formData.append('file', file);
    formData.append('lora_name', props.lora.base_name);
    formData.append('path', props.currentPath);  // 使用当前路径

    try {
        const xhr = new XMLHttpRequest();
        xhr.upload.onprogress = (e) => {
            if (e.lengthComputable) {
                uploadProgress.value = (e.loaded / e.total) * 100;
            }
        };
        
        xhr.onload = async () => {
            if (xhr.status === 200) {
                await loadPreviews();
                showUploadBox.value = false;
            } else {
                alert('上传失败');
            }
            isUploading.value = false;
        };
        
        xhr.onerror = () => {
            alert('上传失败');
            isUploading.value = false;
        };
        
        xhr.open('POST', 'http://localhost:5000/upload-preview');
        xhr.send(formData);
    } catch (error) {
        console.error('上传失败:', error);
        alert('上传失败');
        isUploading.value = false;
    }
}

function handleDragOver(e) {
    e.preventDefault();
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="overlay" @click="handleOverlayClick">
            <div class="detail-card">
                <button class="close-btn" @click="$emit('close')">×</button>
                
                <div class="content-wrapper">
                    <div class="preview-section">
                        <div v-if="previews.length > 0 || lora.has_preview" class="preview-container">
                            <div class="image-wrapper">
                                <img :src="`http://localhost:5000${previews[currentPreviewIndex] || lora.preview_path}`" 
                                     :alt="lora.name" 
                                     class="preview-image"
                                />
                            </div>
                            <div class="controls-wrapper">
                                <div class="preview-controls">
                                    <button @click="previousPreview" 
                                            :disabled="currentPreviewIndex === 0"
                                            class="nav-btn"
                                            @mouseenter="handleButtonHover(true)"
                                            @mouseleave="handleButtonHover(false)">
                                        <span class="btn-content">←</span>
                                        <span class="btn-tooltip">上一张</span>
                                    </button>
                                    <button @click="toggleUploadBox" 
                                            class="add-btn"
                                            @mouseenter="handleButtonHover(true)"
                                            @mouseleave="handleButtonHover(false)">
                                        <span class="btn-content">+</span>
                                        <span class="btn-tooltip">添加预览图</span>
                                    </button>
                                    <button @click="nextPreview" 
                                            :disabled="currentPreviewIndex === previews.length - 1"
                                            class="nav-btn"
                                            @mouseenter="handleButtonHover(true)"
                                            @mouseleave="handleButtonHover(false)">
                                        <span class="btn-content">→</span>
                                        <span class="btn-tooltip">下一张</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                        <div v-else class="no-preview">
                            <div class="no-preview-text">无预览图</div>
                            <div class="controls-wrapper">
                                <button @click="toggleUploadBox" class="add-btn">+</button>
                            </div>
                        </div>
                    </div>

                    <div class="info-section">
                        <h2 class="title">{{ lora.name.replace('.safetensors', '') }}</h2>
                        
                        <div class="metadata-grid">
                            <div class="metadata-item">
                                <span class="label">适用版本</span>
                                <span class="value">{{ lora.metadata?.ss_base_model_version || 'Unknown' }}</span>
                            </div>
                            
                            <div class="metadata-item">
                                <span class="label">Module</span>
                                <span class="value">{{ lora.metadata?.ss_network_module || 'N/A' }}</span>
                            </div>
                            
                            <div class="metadata-item">
                                <span class="label">Dim</span>
                                <span class="value">{{ lora.metadata?.ss_network_dim || 'N/A' }}</span>
                            </div>
                            
                            <div class="metadata-item">
                                <span class="label">Alpha</span>
                                <span class="value">{{ lora.metadata?.ss_network_alpha || 'N/A' }}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <div v-if="showUploadBox" 
                     class="upload-box"
                     @drop="handleDrop"
                     @dragover="handleDragOver">
                    <div class="upload-content" :class="{ 'is-uploading': isUploading }">
                        <template v-if="isUploading">
                            <div class="upload-progress">
                                <div class="progress-bar" :style="{ width: uploadProgress + '%' }"></div>
                            </div>
                            <div class="progress-text">上传中 {{ Math.round(uploadProgress) }}%</div>
                        </template>
                        <template v-else>
                            将图片拖放到此处上传
                        </template>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

.overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.detail-card {
    background: white;
    border-radius: 12px;
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
    padding: 2rem;
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
}

.close-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #666;
    padding: 0.5rem;
    line-height: 1;
}

.content-wrapper {
    display: flex;
    gap: 2rem;
}

.preview-section {
    flex: 1;
    max-width: 50%;
    display: flex;
    flex-direction: column;
}

.info-section {
    flex: 1;
}

.preview-container {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.image-wrapper {
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
    background: #f8f9fa;
    border-radius: 8px;
}

.preview-image {
    max-width: 100%;
    max-height: 400px;
    object-fit: contain;
}

.controls-wrapper {
    display: flex;
    justify-content: center;
    padding: 0.5rem;
}

.preview-controls {
    display: flex;
    gap: 1.5rem;
    align-items: center;
    padding: 1rem 0;
}

.nav-btn, .add-btn {
    position: relative;
    border: none;
    padding: 0.8rem 1.2rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1.2rem;
    transition: all 0.3s ease;
    overflow: visible;
}

.nav-btn {
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    min-width: 3rem;
}

.add-btn {
    background: linear-gradient(135deg, #4caf50, #388e3c);
    color: white;
    min-width: 3rem;
}

.nav-btn:hover:not(:disabled),
.add-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
}

.nav-btn:active:not(:disabled),
.add-btn:active {
    transform: translateY(0);
}

.nav-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
    transform: none;
}

.btn-tooltip {
    position: absolute;
    bottom: -2rem;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(0, 0, 0, 0.8);
    color: white;
    padding: 0.4rem 0.8rem;
    border-radius: 4px;
    font-size: 0.8rem;
    white-space: nowrap;
    opacity: 0;
    transition: opacity 0.3s ease;
    pointer-events: none;
}

.nav-btn:hover .btn-tooltip,
.add-btn:hover .btn-tooltip {
    opacity: 1;
}

.upload-box {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 300px;
    height: 200px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border: 2px dashed #4caf50;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1100;
    transition: all 0.3s ease;
}

.upload-box:hover {
    border-color: #2196f3;
    transform: scale(1.02);
}

.upload-content {
    text-align: center;
    color: #666;
}

.upload-progress {
    width: 100%;
    height: 4px;
    background: #eee;
    border-radius: 2px;
    margin: 1rem 0;
    overflow: hidden;
}

.progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #4caf50, #8bc34a);
    transition: width 0.3s ease;
}

.progress-text {
    font-size: 0.9rem;
    color: #666;
}

.is-uploading {
    pointer-events: none;
}

.no-preview {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    align-items: center;
    padding: 2rem;
    background: #f8f9fa;
    border-radius: 8px;
}

.no-preview-text {
    color: #666;
}

.title {
    font-size: 1.5rem;
    margin-bottom: 1.5rem;
    color: #333;
}

.metadata-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
}

.metadata-item {
    padding: 1rem;
    background: #f8f9fa;
    border-radius: 8px;
}

.label {
    display: block;    font-size: 0.9rem;    color: #666;    margin-bottom: 0.5rem;}.value {
    font-size: 1.1rem;
    color: #333;
    font-weight: 500;
}

.btn-content {
    position: relative;
    z-index: 1;
}
</style>
