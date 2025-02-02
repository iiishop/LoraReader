<script setup>
import { ref, watch, computed } from 'vue';
import { gsap } from 'gsap';
import { TransitionGroup } from 'vue';
import { globalLoraMap, updateLoraData, globalState } from '../utils/globalVar';

const props = defineProps({
    currentPath: {
        type: String,
        default: '/'
    },
    isExpanded: {  // 添加新的 prop
        type: Boolean,
        default: true
    },
    isFilterExpanded: {  // 新增属性
        type: Boolean,
        default: true
    },
    activeFilters: {  // 新增
        type: Object,
        default: () => ({
            versions: [],
            dims: [],
            alphas: []
        })
    }
});

const emit = defineEmits(['filter-expand-change', 'lora-files-change']);

const loraFiles = ref([]);
const error = ref('');
const loading = ref(false);
const searchQuery = ref('');

// 添加排序相关的响应式变量
const sortBy = ref('name');  // 'name' | 'created' | 'modified'
const sortOrder = ref('asc'); // 'asc' | 'desc'

// 添加视图模式状态
const viewMode = ref('grid'); // 'grid' | 'gallery'
const viewModes = [
    { id: 'grid', icon: '⊞', label: '网格视图' },
    { id: 'gallery', icon: '🖼️', label: '画廊视图' }
];

function toggleViewMode() {
    viewMode.value = viewMode.value === 'grid' ? 'gallery' : 'grid';
}

const filteredLoraFiles = computed(() => {
    console.log('开始筛选，当前文件数:', Array.from(globalLoraMap.value.values()).length);
    let result = Array.from(globalLoraMap.value.values());
    
    // 应用搜索过滤
    if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase();
        result = result.filter(lora => 
            lora.base_name.toLowerCase().includes(query)
        );
    }
    
    // 获取筛选条件
    const filters = {
        versions: props.activeFilters.versions || [],
        dims: props.activeFilters.dims || [],
        alphas: props.activeFilters.alphas || [],
        baseModels: props.activeFilters.baseModels || []  // 添加基础模型筛选
    };

    // 基础模型筛选
    if (filters.baseModels.length > 0) {
        result = result.filter(lora => {
            const baseModel = lora.metadata?.base_model;
            return filters.baseModels.includes(baseModel);
        });
    }

    // 版本筛选
    if (filters.versions.length > 0) {
        result = result.filter(lora => {
            const version = lora.metadata?.ss_base_model_version;
            console.log('检查版本:', version, '是否在', filters.versions);
            return filters.versions.includes(version);
        });
    }

    // 维度筛选
    if (filters.dims.length > 0) {
        result = result.filter(lora => {
            const dim = lora.metadata?.ss_network_dim;
            console.log('检查维度:', dim, '是否在', filters.dims);
            return filters.dims.includes(dim);
        });
    }

    // Alpha值筛选
    if (filters.alphas.length > 0) {
        result = result.filter(lora => {
            const alpha = lora.metadata?.ss_network_alpha;
            console.log('检查Alpha:', alpha, '是否在', filters.alphas);
            return filters.alphas.includes(alpha);
        });
    }

    // 添加排序逻辑
    result.sort((a, b) => {
        let compareValue;
        switch (sortBy.value) {
            case 'name':
                compareValue = a.name.localeCompare(b.name);
                break;
            case 'created':
                compareValue = (a.metadata?.created_time || 0) - (b.metadata?.created_time || 0);
                break;
            case 'modified':
                compareValue = (a.metadata?.modified_time || 0) - (b.metadata?.modified_time || 0);
                break;
            default:
                compareValue = 0;
        }
        return sortOrder.value === 'asc' ? compareValue : -compareValue;
    });

    console.log('筛选后文件数:', result.length);
    return result;
});

// 修改点击处理方法
function handleLoraClick(lora) {
    // 在打开 LoraDetail 时，传递当前的筛选状态
    const loraWithFilters = {
        ...lora,
        activeFilters: props.activeFilters  // 保存当前的筛选状态
    };
    globalState.openLoraDetail(loraWithFilters);
}

// 移除不需要的状态和方法
const selectedLora = ref(null);
const showDetail = ref(false);

// GSAP 动画
const onBeforeEnter = (el) => {
    el.style.opacity = 0;
    el.style.transform = 'scale(0.6)';
};

const onEnter = (el, done) => {
    gsap.to(el, {
        opacity: 1,
        scale: 1,
        duration: 0.3,
        onComplete: done
    });
};

const onLeave = (el, done) => {
    gsap.to(el, {
        opacity: 0,
        scale: 0.6,
        duration: 0.3,
        onComplete: done
    });
};

async function loadLoraFiles(path) {
    loading.value = true;
    error.value = '';  // 清除之前的错误
    try {
        const cleanPath = path.replace(/\/+/g, '/');  // 规范化路径
        const response = await fetch(`http://localhost:5000/lora-files?path=${encodeURIComponent(cleanPath)}`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        
        if (data.error) {
            error.value = data.error;
        } else {
            // 暂存当前选中的文件名
            const selectedLoraName = selectedLora.value?.name;
            
            updateLoraData(data.lora_files);
            emit('lora-files-change', data.lora_files);
            
            // 如果之前有选中的文件，找到并更新它
            if (selectedLoraName && showDetail.value) {
                const updatedLora = globalLoraMap.value.get(selectedLoraName);
                if (updatedLora) {
                    selectedLora.value = updatedLora;
                }
            }
        }
    } catch (err) {
        error.value = `加载失败: ${err.message}`;
        console.error('Error loading lora files:', err);
    } finally {
        loading.value = false;
    }
}

const refreshLoraFiles = () => {
    loadLoraFiles(props.currentPath);
};

watch(() => props.currentPath, (newPath) => {
    loadLoraFiles(newPath);
}, { immediate: true });

// 添加切换排序的方法
function toggleSort(field) {
    if (sortBy.value === field) {
        sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
    } else {
        sortBy.value = field;
        sortOrder.value = 'asc';
    }
}

// 添加拖拽相关函数
function handleDragStart(event, lora) {
    console.log('Drag started:', lora);
    event.dataTransfer.setData('application/json', JSON.stringify({
        type: 'lora',
        data: lora,
        sourcePath: props.currentPath
    }));
    // 设置拖动效果
    event.dataTransfer.effectAllowed = 'move';
}
</script>

<template>
    <div class="lora-viewer" :class="{ 
        'list-collapsed': !isExpanded,
        'filter-collapsed': !isFilterExpanded,
        [`view-${viewMode}`]: true
    }">
        <div class="header-controls">
            <div class="search-section">
                <input 
                    type="text" 
                    v-model="searchQuery"
                    placeholder="搜索 Lora..."
                    class="search-input"
                />
                <button 
                    class="view-mode-toggle"
                    :class="{ active: viewMode === 'gallery' }"
                    @click="toggleViewMode"
                    :title="viewMode === 'grid' ? '切换到画廊视图' : '切换到网格视图'"
                >
                    {{ viewMode === 'grid' ? '🖼️' : '⊞' }}
                </button>
            </div>
            <div class="sort-controls">
                <button 
                    @click="toggleSort('name')"
                    :class="{ active: sortBy === 'name' }"
                    class="sort-btn"
                >
                    文件名
                    <span class="sort-indicator" v-if="sortBy === 'name'">
                        {{ sortOrder === 'asc' ? '↑' : '↓' }}
                    </span>
                </button>
                <button 
                    @click="toggleSort('created')"
                    :class="{ active: sortBy === 'created' }"
                    class="sort-btn"
                >
                    创建时间
                    <span class="sort-indicator" v-if="sortBy === 'created'">
                        {{ sortOrder === 'asc' ? '↑' : '↓' }}
                    </span>
                </button>
                <button 
                    @click="toggleSort('modified')"
                    :class="{ active: sortBy === 'modified' }"
                    class="sort-btn"
                >
                    修改时间
                    <span class="sort-indicator" v-if="sortBy === 'modified'">
                        {{ sortOrder === 'asc' ? '↑' : '↓' }}
                    </span>
                </button>
            </div>
        </div>
        
        <div v-if="loading" class="loading">
            加载中...
        </div>
        <div v-else-if="error" class="error">
            {{ error }}
        </div>
        <TransitionGroup 
            v-else 
            :tag="viewMode === 'grid' ? 'div' : 'div'"
            :class="['lora-container', `layout-${viewMode}`]"
            @before-enter="onBeforeEnter"
            @enter="onEnter"
            @leave="onLeave"
        >
            <div v-for="lora in filteredLoraFiles" 
                 :key="lora.name" 
                 :class="['lora-item', `item-${viewMode}`]"
                 @click="handleLoraClick(lora)"
                 draggable="true"
                 @dragstart="handleDragStart($event, lora)">
                <div :class="['preview', `preview-${viewMode}`]">
                    <img v-if="lora.has_preview" 
                         :src="`http://localhost:5000${lora.preview_path}`" 
                         :alt="lora.name"
                         loading="lazy"
                    />
                    <div v-else class="no-preview">无预览图</div>
                </div>
                <div :class="['info', `info-${viewMode}`]">
                    <div class="name">{{ lora.name.replace('.safetensors', '') }}</div>
                    <div class="metadata" v-if="lora.metadata">
                        <span class="model-tag">{{ lora.metadata.base_model }}</span>
                        <span class="version-tag">
                            SD {{ lora.metadata.ss_base_model_version || 'Unknown' }}
                        </span>
                        <div class="metadata-details" v-if="lora.metadata.ss_network_dim">
                            <span class="detail-tag">
                                Dim: {{ lora.metadata.ss_network_dim }}
                            </span>
                            <span class="detail-tag" v-if="lora.metadata.ss_network_alpha">
                                Alpha: {{ lora.metadata.ss_network_alpha }}
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </TransitionGroup>
        
        <button class="refresh-btn" @click="refreshLoraFiles">🔄</button>
    </div>
</template>

<style scoped>
.lora-viewer {
    padding-top: 9rem;  /* 为固定定位的搜索框留出空间 */
}

.lora-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
    position: relative;
    will-change: transform;
}

.lora-card {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: transform 0.2s, box-shadow 0.2s;
    will-change: transform, opacity;
    cursor: pointer;
}

.lora-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.preview {
    aspect-ratio: 1;
    background: #f8f9fa;
    display: flex;
    align-items: center;
    justify-content: center;
}

.preview img {
    width: 100%;
    height: 100%;
    object-fit: contain;
}

.no-preview {
    color: #666;
    font-size: 0.9rem;
}

.info {
    padding: 0.8rem;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
}

.name {
    font-size: 0.9rem;
    margin-bottom: 0.5rem;
    word-break: break-all;
}

.metadata {
    margin: 0.5rem 0;
    font-size: 0.8rem;
}

.version-tag {
    display: inline-block;
    padding: 0.2rem 0.5rem;
    background-color: #e9ecef;
    border-radius: 4px;
    color: #495057;
    font-weight: 500;
}

.metadata-details {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.3rem;
}

.detail-tag {
    display: inline-block;
    padding: 0.1rem 0.4rem;
    background-color: #f8f9fa;
    border-radius: 4px;
    color: #666;
    font-size: 0.75rem;
}

.badges {
    display: flex;
    gap: 0.5rem;
}

.badge {
    font-size: 1rem;
}

.loading {
    text-align: center;
    padding: 2rem;
    color: #666;
}

.error {
    color: #dc3545;
    padding: 1rem;
    background: #fee;
    border-radius: 8px;
    text-align: center;
}

.header-controls {
    position: fixed;
    top: 0;
    left: 300px;
    right: 300px;
    z-index: 100;
    background: white;
    padding: 1rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    transition: all 0.3s ease;
}

.sort-controls {
    display: flex;
    gap: 0.5rem;
    padding: 0.5rem 0;
}

.sort-btn {
    padding: 0.5rem 1rem;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.sort-btn:hover {
    background: #f5f5f5;
}

.sort-btn.active {
    background: #e3f2fd;
    border-color: #1976d2;
    color: #1976d2;
}

.sort-indicator {
    font-weight: bold;
}

/* 调整现有的响应式样式 */
.list-collapsed .header-controls {
    left: 40px;
}

.filter-collapsed .header-controls {
    right: 40px;
}

.list-collapsed.filter-collapsed .header-controls {
    left: 40px;
    right: 40px;
}

.search-container {
    display: flex;
    justify-content: center;
}

.search-input {
    width: 100%;
    max-width: 400px;
    padding: 0.8rem 1rem;
    border: 2px solid #e0e0e0;
    border-radius: 6px;
    font-size: 1rem;
    transition: all 0.2s;
    outline: none;
    background-color: #f8f9fa;
}

.search-input:focus {
    border-color: #4a90e2;
    box-shadow: 0 0 0 3px rgba(74, 144, 226, 0.1);
}

.refresh-btn {
    position: fixed;
    bottom: 100px;
    right: 20px;
    background-color: #4caf50;
    color: white;
    border: none;
    border-radius: 50%;
    width: 60px;
    height: 60px;
    font-size: 1.5rem;
    cursor: pointer;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
    transition: background-color 0.3s ease, transform 0.3s ease;
    z-index: 1000; /* 确保按钮浮动在最上层 */
}

.refresh-btn:hover {
    background-color: #45a049;
    transform: scale(1.1);
}

.refresh-btn:active {
    transform: scale(0.9);
}

.model-tag {
    display: inline-block;
    padding: 0.2rem 0.5rem;
    background-color: #e8f5e9;  /* 使用不同的颜色区分基础模型标签 */
    color: #2e7d32;
    border-radius: 4px;
    font-size: 0.8rem;
    margin-right: 0.5rem;
}

/* 新增样式 */
.search-section {
    display: flex;
    align-items: center;
    gap: 1rem;
    width: 100%;
    max-width: 600px;
    margin: 0 auto;
}

.view-mode-toggle {
    padding: 0.8rem;
    border: 2px solid #e0e0e0;
    border-radius: 6px;
    background: white;
    cursor: pointer;
    font-size: 1.2rem;
    transition: all 0.3s ease;
}

.view-mode-toggle:hover {
    background: #f5f5f5;
    transform: translateY(-2px);
}

.view-mode-toggle.active {
    background: #e3f2fd;
    border-color: #1976d2;
    color: #1976d2;
}

/* Grid Mode Styles */
.layout-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); /* 略微增加最小宽度 */
    gap: 1.5rem; /* 增加间距 */
    padding: 1.5rem;
}

.item-grid {
    display: flex;
    flex-direction: column;
    height: auto;  /* 改为自适应高度 */
    min-height: 300px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.3s ease;
}

.preview-grid {
    flex: 0 0 200px; /* 固定预览图高度 */
    background: #f8f9fa;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
}

.preview-grid img {
    max-width: 100%;
    max-height: 100%;
    width: auto;
    height: auto;
    object-fit: contain;
    transition: transform 0.3s ease;
}

.info-grid {
    flex: 1;
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    overflow: hidden; /* 防止内容溢出 */
}

.name {
    font-size: 0.9rem;
    font-weight: 500;
    color: #333;
    margin-bottom: 0.5rem;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
}

.metadata {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 0.5rem 0;
}

.model-tag, .version-tag {
    font-size: 0.8rem;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    white-space: nowrap;
}

.model-tag {
    background-color: #e8f5e9;
    color: #2e7d32;
}

.version-tag {
    background-color: #e3f2fd;
    color: #1976d2;
}

.metadata-details {
    display: flex;
    flex-wrap: wrap;
    gap: 0.3rem;
    margin-top: 0.3rem;
}

.detail-tag {
    font-size: 0.75rem;
    padding: 0.1rem 0.4rem;
    background-color: #f5f5f5;
    color: #666;
    border-radius: 4px;
    white-space: nowrap;
}

/* Gallery Mode Styles */
.layout-gallery {
    columns: 4 240px;
    column-gap: 1rem;
    padding: 1rem;
}

.item-gallery {
    break-inside: avoid;
    margin-bottom: 1rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.3s ease;
}

.preview-gallery {
    width: 100%;
    position: relative;
    background: #f8f9fa;
}

.preview-gallery img {
    width: 100%;
    height: auto;
    display: block;
    transition: transform 0.3s ease;
}

.info-gallery {
    padding: 1rem;
    background: rgba(255, 255, 255, 0.95);
    transition: transform 0.3s ease;
}

.item-gallery:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
}

.item-gallery:hover .info-gallery {
    transform: translateY(-4px);
}

/* Animation Styles */
.layout-gallery .item-gallery {
    animation: fadeInUp 0.6s ease forwards;
    opacity: 0;
}

@keyframes fadeInUp {
    from {
        opacity: 0;
        transform: translateY(20px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

/* Hover Effects */
.item-gallery::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to top, rgba(0,0,0,0.3), transparent);
    opacity: 0;
    transition: opacity 0.3s ease;
}

.item-gallery:hover::after {
    opacity: 1;
}

/* Loading Animation */
.preview-gallery.loading::before {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    background-size: 200% 100%;
    animation: loading 1.5s infinite;
}

@keyframes loading {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
}

/* Responsive Adjustments */
@media (max-width: 1200px) {
    .layout-grid {
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    }
}

@media (max-width: 768px) {
    .layout-grid {
        grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
        gap: 1rem;
        padding: 1rem;
    }
}

@media (max-width: 768px) {
    .layout-gallery {
        columns: 2 200px;
    }
}

@media (max-width: 480px) {
    .layout-gallery {
        columns: 1 100%;
    }
}

.lora-item {
    /* ... existing styles ... */
    cursor: grab;  /* 添加抓取光标样式 */
}

.lora-item:active {
    cursor: grabbing;  /* 拖动时的光标样式 */
}
</style>
