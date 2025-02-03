<script setup>
import { defineProps, defineEmits, ref, onMounted, watch } from 'vue';
import '@/assets/styles/LoraDetail.css';
import { globalState } from '../utils/globalVar';

const props = defineProps({
    lora: {
        type: Object,
        required: false, // 改为不必需
        default: () => ({}) // 提供默认值
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

// 添加基础模型列表状态
const baseModels = ref([]);
const selectedBaseModel = ref('');

// 重置状态的函数
function resetState() {
    currentPreviewIndex.value = 0;
    previews.value = [];
    if (props.lora?.has_preview) {  // 添加可选链操作符
        previews.value = [props.lora.preview_path];
    }
}

// 监听 lora 的变化
watch(() => props.lora, async (newLora) => {
    if (!newLora) return; // 添加空值检查
    resetState();
    if (newLora.has_preview) {
        await loadPreviews();
    }
}, { deep: true });

// 修改 onMounted
onMounted(async () => {
    if (!props.lora) return; // 添加空值检查
    resetState();
    if (props.lora.has_preview) {
        await loadPreviews();
    }
    loadBaseModels();
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
    if (e.target.classList.contains('lora-overlay')) {
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

// 添加获取基础模型列表的函数
async function loadBaseModels() {
    try {
        const response = await fetch('http://localhost:5000/base-models');
        if (response.ok) {
            baseModels.value = await response.json();
        }
    } catch (error) {
        console.error('Error loading base models:', error);
    }
}

// 修改编辑模式初始化
function startEditing() {
    editedConfig.value = {
        activation_text: props.lora.config?.activation_text || '',
        preferred_weight: props.lora.config?.preferred_weight || 0,
        notes: props.lora.config?.notes || '',
        description: props.lora.config?.description || '',
        base_model: props.lora.config?.base_model || props.lora.metadata?.base_model || '',
        civitai_link: props.lora.config?.civitai_link || '' // 添加 civitai 链接字段
    };
    selectedBaseModel.value = editedConfig.value.base_model;
    isEditing.value = true;
}

// 修改保存配置函数
async function saveConfig() {
    try {
        const configToSave = {
            ...editedConfig.value,
            base_model: selectedBaseModel.value
        };
        
        console.log('Saving config:', {
            path: props.currentPath,
            lora_name: props.lora.base_name,
            config: configToSave
        });

        const response = await fetch('http://localhost:5000/update-config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                path: props.currentPath,
                lora_name: props.lora.base_name,
                config: configToSave
            })
        });

        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || '保存失败');
        }

        // 更新本地数据
        props.lora.config = configToSave;
        props.lora.has_config = true;
        
        // 更新元数据中的基础模型（最高优先级）
        if (props.lora.metadata) {
            props.lora.metadata.base_model = selectedBaseModel.value;
        }
        
        isEditing.value = false;
        
        // 添加成功提示
        alert('配置保存成功！');
        
    } catch (error) {
        console.error('保存配置失败:', error);
        alert(error.message || '保存失败');
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

// 添加处理关闭事件的函数
function handleClose() {
    // 确保关闭时保留筛选状态
    emit('close', props.lora.activeFilters);
}

// 修改图片点击处理方法
function handleImageClick(imageUrl) {
    globalState.openImageDetail(imageUrl); // 移除 zIndex 参数，使用栈长度来计算
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
        <div v-if="show && lora" class="overlay lora-overlay" @click="handleOverlayClick">
            <div class="detail-card">
                <button class="close-btn" @click="handleClose">×</button>
                
                <div class="content-wrapper">
                    <div class="preview-section">
                        <div v-if="previews.length > 0 || lora.has_preview" class="preview-container">
                            <div class="image-wrapper" @click="handleImageClick(`http://localhost:5000${previews[currentPreviewIndex] || lora.preview_path}`)">
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

                            <div class="metadata-item">
                                <span class="label">基础模型</span>
                                <template v-if="isEditing">
                                    <select v-model="selectedBaseModel" class="model-select">
                                        <option value="">-- 选择基础模型 --</option>
                                        <option v-for="model in baseModels" 
                                                :key="model" 
                                                :value="model">
                                            {{ model }}
                                        </option>
                                    </select>
                                </template>
                                <span v-else class="value">
                                    {{ lora.config?.base_model || lora.metadata?.base_model || 'Unknown' }}
                                </span>
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

                                <div class="config-item">
                                    <h3 class="config-title">Civitai 链接</h3>
                                    <input 
                                        type="text" 
                                        v-model="editedConfig.civitai_link"
                                        class="config-input civitai-link"
                                        placeholder="请输入 Civitai 模型页面链接"
                                    />
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

                                    <div v-if="lora.config.civitai_link" class="config-item">
                                        <h3 class="config-title">Civitai 链接</h3>
                                        <div class="config-content civitai-link">
                                            <a :href="lora.config.civitai_link" 
                                               target="_blank" 
                                               rel="noopener noreferrer"
                                               class="civitai-link">
                                                访问 Civitai 页面
                                            </a>
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
                        <button class="close-upload-btn" @click="toggleUploadBox">×</button> <!-- 添加关闭按钮 -->
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

</style>
