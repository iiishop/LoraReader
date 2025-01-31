<script setup>
import { ref, computed } from 'vue';
import { findLorasByName } from '../utils/globalVar';

const props = defineProps({
    show: Boolean
});

const emit = defineEmits(['close', 'created']);

const name = ref('');
const searchQuery = ref('');
const selectedLoras = ref([]);
const positivePrompt = ref('');
const negativePrompt = ref('');
const note = ref('');
const searchResults = ref([]);
const currentPage = ref(1);
const pageSize = 10;

// 排序相关
const sortOptions = ref([
    { label: '相关度', value: 'relevance' },
    { label: '名称', value: 'name' },
    { label: '点击量', value: 'clicks' }
]);
const currentSort = ref('relevance');

// 计算属性：分页后的搜索结果
const displayedResults = computed(() => {
    let results = [...searchResults.value];
    
    // 排序逻辑
    switch(currentSort.value) {
        case 'name':
            results.sort((a, b) => a.name.localeCompare(b.name));
            break;
        case 'clicks':
            results.sort((a, b) => {
                const aClicks = a.search_clicks || 0;
                const bClicks = b.search_clicks || 0;
                if (aClicks !== bClicks) return bClicks - aClicks;
                return (b.global_clicks || 0) - (a.global_clicks || 0);
            });
            break;
        case 'relevance':
        default:
            break;
    }
    
    return results.slice(0, currentPage.value * pageSize);
});

const hasMore = computed(() => {
    return currentPage.value * pageSize < searchResults.value.length;
});

function handleLoraSelect(lora) {
    // 检查是否已经选择
    if (selectedLoras.value.some(l => l.name === lora.name)) {
        return;
    }

    const weight = lora.config?.preferred_weight || 1;
    selectedLoras.value.push({
        ...lora,
        weight,
        activation_text: lora.config?.activation_text || ''
    });
    
    // 添加激活词到正面提示词
    if (lora.config?.activation_text) {
        positivePrompt.value = positivePrompt.value
            ? `${positivePrompt.value}, ${lora.config.activation_text}`
            : lora.config.activation_text;
    }
}

async function handleSubmit() {
    if (!name.value.trim()) {
        alert('请输入组合名称');
        return;
    }

    const combination = {
        name: name.value.trim(),
        loras: selectedLoras.value,
        positive_prompt: positivePrompt.value,
        negative_prompt: negativePrompt.value,
        note: note.value
    };

    try {
        const response = await fetch('http://localhost:5000/lora-combinations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(combination)
        });

        if (!response.ok) throw new Error('保存失败');
        const result = await response.json();
        emit('created', result);
    } catch (error) {
        console.error('Error creating combination:', error);
        alert('保存失败');
    }
}

function handleSearch() {
    console.log("Searching for:", searchQuery.value);
    if (!searchQuery.value.trim()) return;
    
    const results = findLorasByName(searchQuery.value);
    searchResults.value = results;
    currentPage.value = 1;  // 重置页码
}

function loadMore() {
    currentPage.value++;
}

function handleClose() {
    emit('close');
}
</script>

<template>
    <div v-if="show" class="overlay" @click="handleClose">
        <div class="panel" @click.stop>
            <button class="close-btn" @click="handleClose">×</button>
            <h2>新建 Lora 组合</h2>
            
            <div class="form">
                <div class="form-group">
                    <label>组合名称</label>
                    <input v-model="name" type="text" placeholder="输入组合名称">
                </div>

                <div class="search-section">
                    <div class="search-header">
                        <div class="search-box">
                            <input v-model="searchQuery" 
                                   type="text" 
                                   placeholder="搜索 Lora..."
                                   @keyup.enter="handleSearch">
                            <button @click="handleSearch">搜索</button>
                        </div>
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

                    <!-- 搜索结果列表 -->
                    <div v-if="searchResults.length" class="search-results">
                        <div class="result-list">
                            <div v-for="lora in displayedResults" 
                                 :key="lora.name"
                                 class="result-item"
                                 @click="handleLoraSelect(lora)">
                                <div class="preview-section">
                                    <img v-if="lora.has_preview" 
                                         :src="`http://localhost:5000${lora.preview_path}`" 
                                         :alt="lora.name"
                                         class="preview-image" />
                                    <div v-else class="no-preview">无预览图</div>
                                </div>
                                
                                <div class="info-section">
                                    <div class="name">
                                        {{ lora.name.replace('.safetensors', '') }}
                                    </div>
                                    
                                    <div class="metadata" v-if="lora.metadata">
                                        <span class="tag model-tag">
                                            {{ lora.metadata.ss_base_model_version }}
                                        </span>
                                        <span class="tag dim-tag" v-if="lora.metadata.ss_network_dim">
                                            Dim: {{ lora.metadata.ss_network_dim }}
                                        </span>
                                        <span class="tag alpha-tag" v-if="lora.metadata.ss_network_alpha">
                                            Alpha: {{ lora.metadata.ss_network_alpha }}
                                        </span>
                                        <span class="tag clicks-tag" title="点击次数">
                                            👆 {{ lora.global_clicks || 0 }}
                                        </span>
                                    </div>
                                    
                                    <div class="location">
                                        位置: {{ lora.relative_path || '根目录' }}
                                    </div>

                                    <div class="config-info" v-if="lora.has_config">
                                        <div class="activation-text" v-if="lora.config?.activation_text">
                                            触发词: {{ lora.config.activation_text }}
                                        </div>
                                        <div class="weight" v-if="lora.config?.preferred_weight">
                                            推荐权重: {{ lora.config.preferred_weight }}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <button v-if="hasMore" 
                                class="load-more-btn"
                                @click.stop="loadMore">
                            显示更多 ({{ displayedResults.length }}/{{ searchResults.length }})
                        </button>
                    </div>
                </div>

                <!-- 已选择的 Lora -->
                <div class="selected-section">
                    <h3>已选择的 Lora</h3>
                    <div class="selected-loras">
                        <div v-for="lora in selectedLoras" 
                             :key="lora.name" 
                             class="selected-lora">
                            <span class="lora-name">{{ lora.name }}</span>
                            <input type="number" 
                                   v-model.number="lora.weight" 
                                   step="0.1" 
                                   class="weight-input">
                            <button class="remove-btn" 
                                    @click="selectedLoras = selectedLoras.filter(l => l.name !== lora.name)">
                                ×
                            </button>
                        </div>
                    </div>
                </div>

                <!-- 提示词和备注 -->
                <div class="form-group">
                    <label>正面提示词</label>
                    <textarea v-model="positivePrompt" rows="3" 
                             placeholder="输入正面提示词..."></textarea>
                </div>

                <div class="form-group">
                    <label>负面提示词</label>
                    <textarea v-model="negativePrompt" rows="3"
                             placeholder="输入负面提示词..."></textarea>
                </div>

                <div class="form-group">
                    <label>备注</label>
                    <textarea v-model="note" rows="3"
                             placeholder="添加备注..."></textarea>
                </div>

                <div class="buttons">
                    <button class="cancel" @click="handleClose">取消</button>
                    <button class="submit" @click="handleSubmit">保存</button>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
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

.panel {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
}

/* 搜索结果样式 */
.search-results {
    max-height: 400px;
    overflow-y: auto;
    border: 1px solid #eee;
    border-radius: 8px;
    margin: 1rem 0;
}

.result-item {
    display: flex;
    gap: 1rem;
    padding: 1rem;
    border-bottom: 1px solid #eee;
    cursor: pointer;
    transition: all 0.3s ease;
}

.result-item:hover {
    background: #f5f5f5;
    transform: translateY(-2px);
}

.preview {
    width: 80px;
    height: 80px;
    border-radius: 4px;
    overflow: hidden;
}

.preview img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.info {
    flex: 1;
}

.name {
    font-weight: 500;
    margin-bottom: 0.5rem;
}

.metadata {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 0.5rem;
}

.tag {
    font-size: 0.8rem;
    padding: 0.2rem 0.5rem;
    background: #e3f2fd;
    color: #1976d2;
    border-radius: 4px;
}

.clicks-tag {
    background: #fff3e0;
    color: #f57c00;
}

/* 其他样式 */
.search-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.selected-loras {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin: 1rem 0;
}

.selected-lora {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    background: #e3f2fd;
    border-radius: 4px;
}

.weight-input {
    width: 60px;
    text-align: center;
}

.remove-btn {
    padding: 0.2rem 0.5rem;
    background: none;
    border: none;
    color: #666;
    cursor: pointer;
}

/* ...rest of existing styles... */
.panel {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
}

.form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

label {
    font-size: 0.9rem;
    color: #666;
}

input, textarea {
    padding: 0.8rem;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 1rem;
}

.search-box {
    display: flex;
    gap: 1rem;
}

.search-box input {
    flex: 1;
}

.buttons {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
}

.search-results {
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid #eee;
    border-radius: 8px;
}

.search-result-item {
    padding: 1rem;
    border-bottom: 1px solid #eee;
    cursor: pointer;
}

.search-result-item:hover {
    background: #f5f5f5;
}

.selected-loras {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
}

.selected-lora {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem;
    background: #e3f2fd;
    border-radius: 4px;
    font-size: 0.9rem;
}

button {
    padding: 0.8rem 1.5rem;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1rem;
    transition: all 0.3s ease;
}

.submit {
    background: #4caf50;
    color: white;
}

.cancel {
    background: #f5f5f5;
    color: #666;
}

button:hover {
    opacity: 0.9;
    transform: translateY(-1px);
}

.result-list {
    display: flex;
    flex-direction: column;
}

.preview-section {
    width: 100px;
    height: 100px;
    border-radius: 8px;
    overflow: hidden;
    background: #f8f9fa;
}

.preview-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
}

.no-preview {
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #666;
    font-size: 0.9rem;
}

.info-section {
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
    flex-wrap: wrap;
    gap: 0.5rem;
}

.tag {
    font-size: 0.8rem;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
}

.model-tag {
    background: #e3f2fd;
    color: #1976d2;
}

.dim-tag {
    background: #f3e5f5;
    color: #9c27b0;
}

.alpha-tag {
    background: #e8f5e9;
    color: #43a047;
}

.clicks-tag {
    background: #fff3e0;
    color: #f57c00;
}

.location {
    font-size: 0.9rem;
    color: #666;
}

.config-info {
    font-size: 0.9rem;
    color: #555;
    border-left: 3px solid #e0e0e0;
    padding-left: 0.5rem;
    margin-top: 0.5rem;
}
</style>
