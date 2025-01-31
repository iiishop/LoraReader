<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { globalState } from '../utils/globalVar';

const props = defineProps({
    combination: {
        type: Object,
        required: true
    },
    show: Boolean
});

const emit = defineEmits(['close']);
const showFullscreen = ref(false);
const selectedPreviewIndex = ref(0);
const previewList = ref([]);

const showCopySuccess = ref(false);

const formattedPrompt = computed(() => {
    const basePrompt = props.combination.positive_prompt;
    const loraPrompts = props.combination.loras
        .map(l => `<${l.name}:${l.weight}>`)
        .join(', ');
    return `${basePrompt}\n${loraPrompts}`;
});

function handleLoraClick(lora) {
    globalState.openLoraDetail(lora);
}

async function copyPrompt() {
    await navigator.clipboard.writeText(formattedPrompt.value);
    showCopySuccess.value = true;
    setTimeout(() => showCopySuccess.value = false, 2000);
}

const currentPreviewIndex = ref(0);
const previews = ref([]);
const showUploadBox = ref(false);
const isUploading = ref(false);
const uploadProgress = ref(0);

// 加载所有预览图
async function loadPreviews() {
    if (!props.combination?.id) return;
    try {
        const response = await fetch(`http://localhost:5000/combination-previews/${props.combination.id}`);
        if (response.ok) {
            const data = await response.json();
            previewList.value = data.previews.map(p => ({
                url: `http://localhost:5000${p}`,
                isLoaded: false
            }));
        }
    } catch (error) {
        console.error('加载预览图失败:', error);
    }
}

// 监听组合数据变化，加载预览图
watch(() => props.combination, async () => {
    if (props.combination) {
        await loadPreviews();
    }
}, { immediate: true });

// 处理预览图点击
function handlePreviewClick(index) {
    selectedPreviewIndex.value = index;
    showFullscreen.value = true;
}

// 处理上传完成后重新加载
async function handleUploadSuccess() {
    await loadPreviews();
    showUploadBox.value = false;
}

// 关闭全屏预览
function closeFullscreen() {
    showFullscreen.value = false;
}

// 切换到上一张或下一张
function navigatePreview(direction) {
    const newIndex = selectedPreviewIndex.value + direction;
    if (newIndex >= 0 && newIndex < previewList.value.length) {
        selectedPreviewIndex.value = newIndex;
    }
}

// 键盘导航
function handleKeydown(e) {
    if (!showFullscreen.value) return;
    if (e.key === 'ArrowLeft') navigatePreview(-1);
    if (e.key === 'ArrowRight') navigatePreview(1);
    if (e.key === 'Escape') closeFullscreen();
}

onMounted(() => {
    window.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
    window.removeEventListener('keydown', handleKeydown);
});

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

    try {
        const response = await fetch(`http://localhost:5000/combination-preview/${props.combination.id}`, {
            method: 'POST',
            body: formData
        });

        if (response.ok) {
            const result = await response.json();
            await loadPreviews();
            showUploadBox.value = false;
        } else {
            alert('上传失败');
        }
    } catch (error) {
        console.error('上传失败:', error);
        alert('上传失败');
    } finally {
        isUploading.value = false;
    }
}

// 添加一个用于截断文本的计算属性
function truncateText(text, maxLength = 30) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - 3) + '...';
}

async function handleDeletePreview(preview) {
    if (!confirm('确定要删除这张预览图吗？')) return;
    
    try {
        // 从URL中获取文件名
        const filename = preview.url.split('/').pop();
        const response = await fetch(`http://localhost:5000/combination-preview/${props.combination.id}/${filename}`, {
            method: 'DELETE'
        });

        if (response.ok) {
            // 重新加载预览图列表
            await loadPreviews();
            // 如果当前查看的是被删除的图片，重置到第一张
            if (selectedPreviewIndex.value >= previewList.value.length) {
                selectedPreviewIndex.value = Math.max(0, previewList.value.length - 1);
            }
        } else {
            const data = await response.json();
            alert(data.error || '删除失败');
        }
    } catch (error) {
        console.error('删除预览图失败:', error);
        alert('删除失败');
    }
}

</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="combine-detail-overlay" @click="$emit('close')">
            <div class="detail-card" @click.stop>
                <button class="close-btn" @click="$emit('close')">×</button>
                
                <div class="content-wrapper">
                    <header class="detail-header">
                        <h2 class="title">{{ combination.name }}</h2>
                        <div class="meta-info">
                            <span class="created-at">
                                创建于: {{ new Date(combination.created_at * 1000).toLocaleString() }}
                            </span>
                        </div>
                    </header>

                    <div class="previews-section">
                        <div class="previews-container">
                            <div class="previews-scroll">
                                <template v-if="previewList.length">
                                    <div v-for="(preview, index) in previewList" 
                                         :key="index"
                                         class="preview-item">
                                        <img :src="preview.url" 
                                             :alt="`预览图 ${index + 1}`"
                                             @load="preview.isLoaded = true"
                                             @click="handlePreviewClick(index)">
                                        <button v-if="previewList.length > 1"
                                                class="delete-preview-btn"
                                                @click.stop="handleDeletePreview(preview)">
                                            ×
                                        </button>
                                    </div>
                                </template>
                                <div class="preview-upload-btn" @click="showUploadBox = true">
                                    <span>+</span>
                                    <div>添加预览图</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="loras-section">
                        <h3 class="section-title">包含的 Lora</h3>
                        <div class="lora-list">
                            <div v-for="lora in combination.loras" 
                                 :key="lora.name"
                                 class="lora-item"
                                 @click="handleLoraClick(lora)">
                                <img v-if="lora.preview_path" 
                                     :src="`http://localhost:5000${lora.preview_path}`" 
                                     :alt="lora.name"
                                     class="lora-preview" />
                                <div class="lora-info">
                                    <span class="lora-name" :title="lora.name">
                                        {{ truncateText(lora.name.replace('.safetensors', '')) }}
                                    </span>
                                    <span class="lora-weight">权重: {{ lora.weight }}</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="prompts-section">
                        <div class="prompt-container">
                            <div class="prompt-header">
                                <h3 class="section-title">提示词</h3>
                                <button @click="copyPrompt" 
                                        class="copy-btn"
                                        :class="{ success: showCopySuccess }">
                                    {{ showCopySuccess ? '已复制!' : '复制完整提示词' }}
                                </button>
                            </div>
                            <div class="prompt-content">
                                <div class="prompt-box positive">
                                    <h4>正面提示词</h4>
                                    <p>{{ combination.positive_prompt }}</p>
                                </div>
                                <div class="prompt-box negative">
                                    <h4>负面提示词</h4>
                                    <p>{{ combination.negative_prompt }}</p>
                                </div>
                                <div class="prompt-box lora-prompts">
                                    <h4>Lora 参数</h4>
                                    <p>{{ combination.loras.map(l => `<${l.name}:${l.weight}>`).join(', ') }}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="notes-section" v-if="combination.note">
                        <h3 class="section-title">备注</h3>
                        <div class="note-content">{{ combination.note }}</div>
                    </div>
                </div>

                <Transition name="fade">
                    <div v-if="showFullscreen" 
                         class="fullscreen-preview"
                         @click="closeFullscreen">
                        <div class="fullscreen-content" @click.stop>
                            <img :src="previewList[selectedPreviewIndex].url" 
                                 :alt="`预览图 ${selectedPreviewIndex + 1}`">
                            
                            <button v-if="selectedPreviewIndex > 0"
                                    class="nav-btn prev"
                                    @click="navigatePreview(-1)">
                                ←
                            </button>
                            <button v-if="selectedPreviewIndex < previewList.length - 1"
                                    class="nav-btn next"
                                    @click="navigatePreview(1)">
                                →
                            </button>
                            <button class="close-btn" @click="closeFullscreen">×</button>
                        </div>
                    </div>
                </Transition>

                <div v-if="showUploadBox" 
                     class="upload-overlay"
                     @drop.prevent="handleDrop"
                     @dragover.prevent>
                    <div class="upload-box">
                        <button class="close-upload-btn" @click="showUploadBox = false">×</button>
                        <div class="upload-content" :class="{ 'is-uploading': isUploading }">
                            <template v-if="isUploading">
                                <div class="upload-progress">
                                    <div class="progress-bar" :style="{ width: uploadProgress + '%' }"></div>
                                </div>
                                <div class="progress-text">上传中 {{ Math.round(uploadProgress) }}%</div>
                            </template>
                            <template v-else>
                                <div class="upload-icon">📁</div>
                                <div class="upload-text">拖放图片到此处或点击上传</div>
                            </template>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.combine-detail-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
}

.detail-card {
    background: white;
    border-radius: 16px;
    width: 90%;
    max-width: 900px;
    max-height: 90vh;
    padding: 2rem;
    position: relative;
    overflow-y: auto;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
}

.content-wrapper {
    display: flex;
    flex-direction: column;
    gap: 2rem;
}

.detail-header {
    border-bottom: 2px solid #eee;
    padding-bottom: 1rem;
}

.title {
    font-size: 1.8rem;
    color: #2c3e50;
    margin-bottom: 0.5rem;
}

.meta-info {
    color: #666;
    font-size: 0.9rem;
}

.preview-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
}

.preview-container {
    width: 100%;
    max-height: 400px;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.preview-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
}

.section-title {
    font-size: 1.2rem;
    color: #2c3e50;
    margin-bottom: 1rem;
}

.lora-list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
}

.lora-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.8rem;
    background: #f8f9fa;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
    /* 添加以下样式 */
    min-width: 0; /* 允许flex子项收缩 */
    overflow: hidden; /* 确保内容不会溢出 */
}

.lora-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.lora-preview {
    width: 50px;
    height: 50px;
    border-radius: 6px;
    object-fit: cover;
}

.lora-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    min-width: 0; /* 允许flex子项收缩 */
}

.lora-name {
    font-weight: 500;
    color: #333;
    white-space: nowrap; /* 防止文本换行 */
    overflow: hidden; /* 隐藏溢出内容 */
    text-overflow: ellipsis; /* 显示省略号 */
}

.lora-weight {
    font-size: 0.9rem;
    color: #666;
    white-space: nowrap;
}

.prompt-container {
    background: #f8f9fa;
    border-radius: 12px;
    padding: 1.5rem;
}

.prompt-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.prompt-content {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.prompt-box {
    background: white;
    border-radius: 8px;
    padding: 1rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.prompt-box h4 {
    color: #666;
    margin-bottom: 0.5rem;
    font-size: 0.9rem;
}

.prompt-box p {
    color: #333;
    white-space: pre-wrap;
    word-break: break-word;
}

.copy-btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 6px;
    background: #4caf50;
    color: white;
    cursor: pointer;
    transition: all 0.3s ease;
}

.copy-btn.success {
    background: #388e3c;
}

.action-btn {
    padding: 0.8rem 1.5rem;
    border: none;
    border-radius: 8px;
    background: #1976d2;
    color: white;
    cursor: pointer;
    transition: all 0.3s ease;
}

.action-btn:hover {
    background: #1565c0;
    transform: translateY(-1px);
}

/* 上传框样式 */
.upload-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2100;
}

.upload-box {
    background: white;
    border-radius: 16px;
    padding: 2rem;
    width: 90%;
    max-width: 500px;
    position: relative;
}

.upload-content {
    border: 2px dashed #ddd;
    border-radius: 12px;
    padding: 3rem;
    text-align: center;
    cursor: pointer;
    transition: all 0.3s ease;
}

.upload-content:hover {
    border-color: #1976d2;
    background: #f5f5f5;
}

.upload-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
}

.upload-progress {
    height: 4px;
    background: #eee;
    border-radius: 2px;
    overflow: hidden;
    margin: 1rem 0;
}

.progress-bar {
    height: 100%;
    background: #4caf50;
    transition: width 0.3s ease;
}

/* 其他样式保持不变 */

.previews-section {
    margin: 1rem 0;
}

.previews-container {
    width: 100%;
    overflow: hidden;
    margin: 1rem 0;
}

.previews-scroll {
    display: flex;
    gap: 1rem;
    overflow-x: auto;
    padding: 1rem;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch;
}

.preview-item {
    position: relative;
    flex: 0 0 200px;
    height: 200px;
    border-radius: 8px;
    overflow: hidden;
    cursor: pointer;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    transition: transform 0.2s;
}

.preview-item:hover {
    transform: translateY(-4px);
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

.preview-item img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.preview-upload-btn {
    flex: 0 0 200px;
    height: 200px;
    border: 2px dashed #ddd;
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.3s;
}

.preview-upload-btn:hover {
    border-color: #1976d2;
    background: #f5f5f5;
}

.preview-upload-btn span {
    font-size: 2rem;
    margin-bottom: 0.5rem;
    color: #666;
}

.fullscreen-preview {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.9);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2200;
}

.fullscreen-content {
    position: relative;
    max-width: 90vw;
    max-height: 90vh;
}

.fullscreen-content img {
    max-width: 100%;
    max-height: 90vh;
    object-fit: contain;
}

.nav-btn {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(255, 255, 255, 0.2);
    border: none;
    color: white;
    font-size: 2rem;
    padding: 1rem;
    cursor: pointer;
    transition: background-color 0.3s;
}

.nav-btn:hover {
    background: rgba(255, 255, 255, 0.3);
}

.nav-btn.prev {
    left: -60px;
}

.nav-btn.next {
    right: -60px;
}

.delete-preview-btn {
    position: absolute;
    top: 8px;
    right: 8px;
    width: 24px;
    height: 24px;
    border-radius: 12px;
    background: rgba(255, 0, 0, 0.8);
    color: white;
    border: none;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.3s;
    z-index: 1;
    font-size: 16px;
    padding: 0;
    line-height: 1;
}

.preview-item:hover .delete-preview-btn {
    opacity: 1;
}

.delete-preview-btn:hover {
    background: rgba(255, 0, 0, 1);
    transform: scale(1.1);
}
</style>
