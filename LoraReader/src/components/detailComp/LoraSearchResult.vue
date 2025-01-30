<script setup>
import { defineProps, defineEmits, ref, computed, watch } from 'vue';
import { globalState } from '../../utils/globalVar';

const props = defineProps({
    searchResults: {
        type: Array,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    },
    searchTerm: {
        type: String,
        default: ''
    }
});

const emit = defineEmits(['close']);
const pageSize = 10;
const currentDisplayCount = ref(pageSize);

// 计算当前应该显示的结果
const displayedResults = computed(() => {
    return props.searchResults.slice(0, currentDisplayCount.value);
});

// 计算是否还有更多结果
const hasMore = computed(() => {
    return currentDisplayCount.value < props.searchResults.length;
});

function loadMore() {
    currentDisplayCount.value += pageSize;
}

function handleLoraSelect(lora) {
    globalState.openLoraDetail(lora);
    emit('close');
}

function handleOverlayClick(e) {
    if (e.target.classList.contains('search-overlay')) {
        emit('close');
    }
}

// 重置页面计数
watch(() => props.show, (newVal) => {
    if (newVal) {
        currentDisplayCount.value = pageSize;
    }
});

// 添加排序功能
const sortOptions = ref([
    { label: '相关度', value: 'relevance' },
    { label: '名称', value: 'name' }
]);
const currentSort = ref('relevance');

const sortedResults = computed(() => {
    let results = [...props.searchResults];
    switch(currentSort.value) {
        case 'name':
            return results.sort((a, b) => a.name.localeCompare(b.name));
        case 'relevance':
        default:
            return results; // 保持原有排序（按相似度）
    }
});

</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="search-overlay" @click="handleOverlayClick">
            <div class="search-card" @click.stop>
                <button class="close-btn" @click="$emit('close')">×</button>
                <div class="content">
                    <div class="search-header">
                        <h2 class="search-title">
                            搜索结果: "{{ searchTerm }}"
                            <span class="result-count">(共 {{ searchResults.length }} 个)</span>
                        </h2>
                        <div class="sort-control">
                            <select v-model="currentSort">
                                <option v-for="option in sortOptions" 
                                        :key="option.value" 
                                        :value="option.value">
                                    {{ option.label }}
                                </option>
                            </select>
                        </div>
                    </div>
                    <div class="results-list">
                        <div v-for="lora in displayedResults" 
                             :key="lora.name"
                             class="result-item"
                             @click="handleLoraSelect(lora)">
                            <div class="preview">
                                <img v-if="lora.has_preview" 
                                     :src="`http://localhost:5000${lora.preview_path}`" 
                                     :alt="lora.name" />
                                <div v-else class="no-preview">无预览图</div>
                            </div>
                            <div class="info">
                                <div class="name">{{ lora.name.replace('.safetensors', '') }}</div>
                                <div class="metadata" v-if="lora.metadata">
                                    <span class="tag">{{ lora.metadata.ss_base_model_version }}</span>
                                    <span class="tag" v-if="lora.metadata.ss_network_dim">
                                        Dim: {{ lora.metadata.ss_network_dim }}
                                    </span>
                                </div>
                                <div class="path">位置: {{ lora.relative_path || '根目录' }}</div>
                            </div>
                        </div>
                        
                        <!-- 添加加载更多按钮 -->
                        <button v-if="hasMore" 
                                class="load-more-btn"
                                @click.stop="loadMore">
                            显示更多 ({{ displayedResults.length }}/{{ searchResults.length }})
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.search-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 3000;
}

.search-card {
    background: white;
    border-radius: 12px;
    width: 90%;
    max-width: 600px;
    max-height: 80vh;
    position: relative;
    padding: 2rem;
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
}

.content {
    overflow-y: auto;
    max-height: calc(80vh - 4rem);
}

.search-title {
    font-size: 1.2rem;
    color: #333;
    margin-bottom: 1.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #eee;
}

.results-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.result-item {
    display: flex;
    gap: 1rem;
    padding: 1rem;
    border-radius: 8px;
    background: #f8f9fa;
    cursor: pointer;
    transition: all 0.3s ease;
}

.result-item:hover {
    background: #e9ecef;
    transform: translateY(-2px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.preview {
    width: 80px;
    height: 80px;
    background: #eee;
    border-radius: 4px;
    overflow: hidden;
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
    font-size: 0.8rem;
    text-align: center;
}

.info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.name {
    font-weight: 500;
    color: #333;
}

.metadata {
    display: flex;
    gap: 0.5rem;
}

.tag {
    font-size: 0.8rem;
    padding: 0.2rem 0.5rem;
    background: #e3f2fd;
    color: #1976d2;
    border-radius: 4px;
}

.path {
    font-size: 0.8rem;
    color: #666;
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

.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

.result-count {
    font-size: 0.9rem;
    color: #666;
    margin-left: 0.5rem;
}

.load-more-btn {
    width: 100%;
    padding: 1rem;
    margin-top: 1rem;
    background: #f0f2f5;
    border: none;
    border-radius: 8px;
    color: #1976d2;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all 0.3s ease;
}

.load-more-btn:hover {
    background: #e3f2fd;
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.load-more-btn:active {
    transform: translateY(0);
}

.search-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #eee;
}

.sort-control select {
    padding: 0.3rem 0.8rem;
    border-radius: 4px;
    border: 1px solid #ddd;
    background-color: white;
    font-size: 0.9rem;
    color: #666;
    cursor: pointer;
}

.sort-control select:hover {
    border-color: #bbb;
}
</style>
