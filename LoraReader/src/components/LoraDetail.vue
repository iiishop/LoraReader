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
const isEditing = ref(false);
const editedConfig = ref(null);
const showCopySuccess = ref(false);

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

async function setAsMainPreview() {
    try {
        const response = await fetch('http://localhost:5000/swap-preview', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                path: props.currentPath,
                lora_name: props.lora.base_name,
                preview_index: currentPreviewIndex.value
            })
        });

        if (response.ok) {
            // 重新加载预览图列表
            await loadPreviews();
            // 重置索引到第一张
            currentPreviewIndex.value = 0;
        } else {
            alert('设置主预览图失败');
        }
    } catch (error) {
        console.error('设置主预览图失败:', error);
        alert('设置主预览图失败');
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

function startEditing() {
    editedConfig.value = {
        activation_text: props.lora.config?.activation_text || '',
        preferred_weight: props.lora.config?.preferred_weight || 0,
        notes: props.lora.config?.notes || '',
        description: props.lora.config?.description || ''
    };
    isEditing.value = true;
}

async function saveConfig() {
    try {
        const response = await fetch('http://localhost:5000/update-config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                path: props.currentPath,
                lora_name: props.lora.base_name,
                config: editedConfig.value
            })
        });

        if (response.ok) {
            const result = await response.json();
            // 更新本地状态
            props.lora.config = { ...editedConfig.value };
            props.lora.has_config = result.has_config; // 添加这行
            isEditing.value = false;
        } else {
            alert('保存失败');
        }
    } catch (error) {
        console.error('保存配置失败:', error);
        alert('保存失败');
    }
}

async function copyActivationText(text) {
    try {
        await navigator.clipboard.writeText(text);
        showCopySuccess.value = true;
        setTimeout(() => {
            showCopySuccess.value = false;
        }, 2000);
    } catch (err) {
        console.error('复制失败:', err);
    }
}

function handleClose() {
    // 重置所有状态
    isEditing.value = false;
    editedConfig.value = null;
    showUploadBox.value = false;
    currentPreviewIndex.value = 0;
    emit('close');
}

// 监听 show 属性变化
watch(() => props.show, (newVal) => {
    if (!newVal) {
        // 当面板关闭时重置状态
        isEditing.value = false;
        editedConfig.value = null;
    }
});
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="overlay" @click="handleOverlayClick">
            <div class="detail-card">
                <button class="close-btn" @click="handleClose">×</button>
                
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
                                    <!-- 添加设为主预览图按钮 -->
                                    <button v-if="currentPreviewIndex > 0"
                                            @click="setAsMainPreview"
                                            class="set-main-btn"
                                            @mouseenter="handleButtonHover(true)"
                                            @mouseleave="handleButtonHover(false)">
                                        <span class="btn-content">★</span>
                                        <span class="btn-tooltip">设为主预览图</span>
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

                        <!-- 修改配置信息显示部分 -->
                        <div class="config-section">
                            <div class="config-header">
                                <h3>配置信息</h3>
                                <button v-if="!isEditing" 
                                        @click="startEditing" 
                                        class="edit-btn">
                                    {{ lora.has_config ? '编辑' : '创建配置' }}
                                </button>
                                <button v-else 
                                        @click="saveConfig" 
                                        class="save-btn">
                                    保存
                                </button>
                            </div>

                            <template v-if="isEditing">
                                <div class="config-item">
                                    <h3 class="config-title">触发词</h3>
                                    <textarea 
                                        v-model="editedConfig.activation_text"
                                        class="config-input activation-text"
                                        rows="3"
                                    ></textarea>
                                </div>
                                
                                <div class="config-item">
                                    <h3 class="config-title">推荐权重</h3>
                                    <input 
                                        type="number" 
                                        v-model.number="editedConfig.preferred_weight"
                                        class="config-input weight"
                                        step="0.1"
                                    />
                                </div>
                                
                                <div class="config-item">
                                    <h3 class="config-title">备注</h3>
                                    <textarea 
                                        v-model="editedConfig.notes"
                                        class="config-input notes"
                                        rows="5"
                                    ></textarea>
                                </div>
                            </template>
                            <template v-else>
                                <template v-if="lora.has_config">
                                    <!-- ...existing config display... -->
                                    <div v-if="lora.config.activation_text" class="config-item">
                                        <div class="config-header">
                                            <h3 class="config-title">触发词</h3>
                                            <button @click="copyActivationText(lora.config.activation_text)" 
                                                    class="copy-btn"
                                                    :class="{ 'success': showCopySuccess }">
                                                {{ showCopySuccess ? '已复制!' : '复制' }}
                                            </button>
                                        </div>
                                        <div class="config-content activation-text">
                                            {{ lora.config.activation_text }}
                                        </div>
                                    </div>
                                    
                                    <div v-if="lora.config.preferred_weight" class="config-item">
                                        <h3 class="config-title">推荐权重</h3>
                                        <div class="config-content weight">
                                            {{ lora.config.preferred_weight }}
                                        </div>
                                    </div>
                                    
                                    <div v-if="lora.config.notes" class="config-item">
                                        <h3 class="config-title">备注</h3>
                                        <div class="config-content notes">
                                            <pre>{{ lora.config.notes }}</pre>
                                        </div>
                                    </div>

                                    <div v-if="lora.config.description" class="config-item">
                                        <h3 class="config-title">描述</h3>
                                        <div class="config-content description">
                                            {{ lora.config.description }}
                                        </div>
                                    </div>
                                </template>
                                <div v-else class="no-config-message">
                                    尚未创建配置文件，点击"创建配置"来添加触发词等信息
                                </div>
                            </template>
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

.nav-btn, .add-btn, .set-main-btn {
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

.set-main-btn {
    background: linear-gradient(135deg, #ffd700, #ffa000);
    color: white;
    min-width: 3rem;
}

.nav-btn:hover:not(:disabled),
.add-btn:hover,
.set-main-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
}

.nav-btn:active:not(:disabled),
.add-btn:active,
.set-main-btn:active {
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
.add-btn:hover .btn-tooltip,
.set-main-btn:hover .btn-tooltip {
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

.config-section {
    margin-top: 2rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.config-item {
    background: #f8f9fa;
    border-radius: 8px;
    padding: 1rem;
}

.config-title {
    font-size: 1rem;
    color: #666;
    margin-bottom: 0.5rem;
}

.config-content {
    font-size: 0.9rem;
    line-height: 1.5;
    color: #333;
}

.activation-text {
    font-family: monospace;
    background: #edf2f7;
    padding: 0.5rem;
    border-radius: 4px;
    white-space: pre-wrap;
}

.weight {
    font-size: 1.2rem;
    font-weight: 500;
    color: #2196f3;
}

.notes {
    white-space: pre-wrap;
}

.notes pre {
    margin: 0;
    font-family: inherit;
    white-space: pre-wrap;
}

.description {
    font-style: italic;
    color: #666;
}

.config-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.edit-btn, .save-btn {
    padding: 0.5rem 1rem;
    border-radius: 4px;
    border: none;
    cursor: pointer;
    font-size: 0.9rem;
    transition: all 0.3s ease;
}

.edit-btn {
    background: #f0f0f0;
    color: #666;
}

.save-btn {
    background: #4caf50;
    color: white;
}

.edit-btn:hover {
    background: #e0e0e0;
}

.save-btn:hover {
    background: #388e3c;
}

.config-input {
    width: 100%;
    padding: 0.8rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 0.9rem;
    background: white;
    transition: all 0.3s ease;
}

.config-input:focus {
    border-color: #4a90e2;
    box-shadow: 0 0 0 2px rgba(74, 144, 226, 0.1);
    outline: none;
}

.config-input.activation-text {
    font-family: monospace;
}

.config-input.weight {
    width: 100px;
    text-align: center;
    font-size: 1.1rem;
    color: #2196f3;
}

.config-input.notes {
    font-family: inherit;
    line-height: 1.5;
    resize: vertical;
}

.copy-btn {
    padding: 0.3rem 0.8rem;
    border-radius: 4px;
    border: 1px solid #e0e0e0;
    background: white;
    color: #666;
    font-size: 0.8rem;
    cursor: pointer;
    transition: all 0.3s ease;
}

.copy-btn:hover {
    background: #f5f5f5;
    border-color: #ccc;
}

.copy-btn.success {
    background: #4caf50;
    color: white;
    border-color: #4caf50;
}

.no-config-message {
    text-align: center;
    color: #666;
    padding: 2rem;
    background: #f8f9fa;
    border-radius: 8px;
    font-style: italic;
}
</style>
