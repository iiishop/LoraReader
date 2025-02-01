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
</script>

<template>
    <div class="lora-viewer" :class="{ 
        'list-collapsed': !isExpanded,
        'filter-collapsed': !isFilterExpanded 
    }">
        <div class="header-controls">
            <div class="search-container">
                <input 
                    type="text" 
                    v-model="searchQuery"
                    placeholder="搜索 Lora..."
                    class="search-input"
                />
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
            tag="div" 
            class="lora-grid"
            @before-enter="onBeforeEnter"
            @enter="onEnter"
            @leave="onLeave"
        >
            <div v-for="lora in filteredLoraFiles" 
                 :key="lora.name" 
                 class="lora-card"
                 @click="handleLoraClick(lora)">
                <div class="preview">
                    <img v-if="lora.has_preview" :src="`http://localhost:5000${lora.preview_path}`" :alt="lora.name" />
                    <div v-else class="no-preview">
                        无预览图
                    </div>
                </div>
                <div class="info">
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
                    <div class="badges">
                        <span class="badge" title="配置文件">
                            {{ lora.has_config ? '📄' : '❌' }}
                        </span>
                    </div>
                </div>
            </div>
        </TransitionGroup>
        
        <!-- 移除 LoraDetail 组件 -->
        <button class="refresh-btn" @click="refreshLoraFiles">🔄</button>
    </div>
</template>

<style scoped>
.lora-viewer {
    padding-top: 5rem;  /* 为固定定位的搜索框留出空间 */
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
</style>
