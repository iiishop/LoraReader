<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
    isExpanded: {
        type: Boolean,
        default: true
    },
    loraFiles: {
        type: Array,
        default: () => []
    }
});

const emit = defineEmits(['expand-change', 'filter-change']);

// 分析数据，获取唯一值
const metadata = computed(() => {
    const result = {
        versions: new Set(),
        dims: new Set(),
        alphas: new Set(),
        baseModels: new Set()  // 添加基础模型集合
    };
    console.log(props.loraFiles);
    props.loraFiles.forEach(lora => {
        if (lora.metadata) {
            if (lora.metadata.ss_base_model_version) {
                result.versions.add(lora.metadata.ss_base_model_version);
            }
            if (lora.metadata.ss_network_dim) {
                result.dims.add(lora.metadata.ss_network_dim);
            }
            if (lora.metadata.ss_network_alpha) {
                result.alphas.add(lora.metadata.ss_network_alpha);
            }
            if (lora.metadata.base_model) {
                result.baseModels.add(lora.metadata.base_model);
            }
        }
    });

    return {
        versions: Array.from(result.versions).sort(),
        dims: Array.from(result.dims).sort((a, b) => Number(a) - Number(b)),
        alphas: Array.from(result.alphas).sort((a, b) => Number(a) - Number(b)),
        baseModels: Array.from(result.baseModels).sort()  // 添加基础模型数组
    };
});

// 选中的筛选条件
const selectedFilters = ref({
    versions: new Set(),
    dims: new Set(),
    alphas: new Set(),
    baseModels: new Set()  // 添加基础模型筛选
});

// 修改 emitFilterChange 函数添加更多日志
function emitFilterChange() {
    const filters = {
        versions: Array.from(selectedFilters.value.versions),
        dims: Array.from(selectedFilters.value.dims),
        alphas: Array.from(selectedFilters.value.alphas),
        baseModels: Array.from(selectedFilters.value.baseModels) // 添加基础模型筛选
    };
    console.log('Emitting filters:', filters);
    emit('filter-change', filters);
}

// 添加 watch 以监控 loraFiles 变化时清空选择
watch(() => props.loraFiles, () => {
    selectedFilters.value = {
        versions: new Set(),
        dims: new Set(),
        alphas: new Set(),
        baseModels: new Set()
    };
    emitFilterChange();
}, { deep: true });

// 替换原有的 watch，分开处理每种筛选条件
watch(() => selectedFilters.value.versions, () => emitFilterChange(), { deep: true });
watch(() => selectedFilters.value.dims, () => emitFilterChange(), { deep: true });
watch(() => selectedFilters.value.alphas, () => emitFilterChange(), { deep: true });
watch(() => selectedFilters.value.baseModels, () => emitFilterChange(), { deep: true });

// 添加筛选项计数
const filterCounts = computed(() => ({
    versions: selectedFilters.value.versions.size,
    dims: selectedFilters.value.dims.size,
    alphas: selectedFilters.value.alphas.size,
    baseModels: selectedFilters.value.baseModels.size
}));

// 清除所有筛选
function clearAllFilters() {
    selectedFilters.value = {
        versions: new Set(),
        dims: new Set(),
        alphas: new Set(),
        baseModels: new Set()
    };
    emitFilterChange();
}

</script>

<template>
    <div class="filter-sidebar" :class="{ 'collapsed': !isExpanded }">
        <button class="toggle-btn" @click="$emit('expand-change', !isExpanded)">
            {{ isExpanded ? '▶' : '◀' }}
        </button>
        
        <div class="content" v-if="isExpanded">
            <div class="filter-header">
                <h2>筛选</h2>
                <button 
                    v-if="filterCounts.versions + filterCounts.dims + filterCounts.alphas + filterCounts.baseModels > 0"
                    class="clear-all-btn"
                    @click="clearAllFilters"
                >
                    清除全部
                </button>
            </div>
            
            <!-- SD 版本筛选 -->
            <div class="filter-section" v-if="metadata.versions.length">
                <div class="section-header">
                    <h3>SD 版本</h3>
                    <span class="count-badge" v-if="filterCounts.versions">
                        {{ filterCounts.versions }}/{{ metadata.versions.length }}
                    </span>
                </div>
                <div class="filter-group">
                    <label v-for="version in metadata.versions" :key="version">
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.versions"
                            :value="version"
                        >
                        <span class="checkbox-label">{{ version }}</span>
                    </label>
                </div>
            </div>
            
            <!-- 维度筛选 -->
            <div class="filter-section" v-if="metadata.dims.length">
                <div class="section-header">
                    <h3>维度</h3>
                    <span class="count-badge" v-if="filterCounts.dims">
                        {{ filterCounts.dims }}/{{ metadata.dims.length }}
                    </span>
                </div>
                <div class="filter-group chips">
                    <label 
                        v-for="dim in metadata.dims" 
                        :key="dim"
                        class="chip"
                        :class="{ active: selectedFilters.dims.has(dim) }"
                    >
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.dims"
                            :value="dim"
                        >
                        <span>{{ dim }}</span>
                    </label>
                </div>
            </div>
            
            <!-- Alpha 值筛选 -->
            <div class="filter-section" v-if="metadata.alphas.length">
                <div class="section-header">
                    <h3>Alpha 值</h3>
                    <span class="count-badge" v-if="filterCounts.alphas">
                        {{ filterCounts.alphas }}/{{ metadata.alphas.length }}
                    </span>
                </div>
                <div class="filter-group chips">
                    <label 
                        v-for="alpha in metadata.alphas" 
                        :key="alpha"
                        class="chip"
                        :class="{ active: selectedFilters.alphas.has(alpha) }"
                    >
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.alphas"
                            :value="alpha"
                        >
                        <span>{{ alpha }}</span>
                    </label>
                </div>
            </div>

            <!-- 添加基础模型筛选部分 -->
            <div class="filter-section" v-if="metadata.baseModels.length">
                <div class="section-header">
                    <h3>基础模型</h3>
                    <span class="count-badge" v-if="filterCounts.baseModels">
                        {{ filterCounts.baseModels }}/{{ metadata.baseModels.length }}
                    </span>
                </div>
                <div class="filter-group">
                    <label v-for="model in metadata.baseModels" :key="model">
                        <input 
                            type="checkbox"
                            :value="model"
                            :checked="selectedFilters.baseModels.has(model)"
                            @change="e => {
                                if (e.target.checked) {
                                    selectedFilters.baseModels.add(model)
                                } else {
                                    selectedFilters.baseModels.delete(model)
                                }
                            }"
                        >
                        <span class="checkbox-label">{{ model }}</span>
                    </label>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
.filter-sidebar {
    position: fixed;
    right: 0;
    top: 0;
    bottom: 6rem;
    background: white;
    width: 300px;
    box-shadow: -2px 0 5px rgba(0, 0, 0, 0.1);
    transition: width 0.3s ease;
    overflow-x: hidden;
    display: flex;
}

.filter-sidebar.collapsed {
    width: 40px;
}

.toggle-btn {
    position: absolute;
    left: 0;
    top: 50%;
    transform: translateY(-50%);
    background: #4a90e2;
    color: white;
    border: none;
    width: 24px;
    height: 40px;
    cursor: pointer;
    z-index: 2;
    border-radius: 4px 0 0 4px;
    padding: 0;
    font-size: 12px;
}

.content {
    flex: 1;
    padding: 1rem;
    padding-top: 4rem; /* 为顶部搜索框留出空间 */
    overflow-y: auto;
}

.filter-section {
    margin-bottom: 2rem;
}

h2 {
    color: #333;
    margin-bottom: 1.5rem;
    font-size: 1.2rem;
}

h3 {
    color: #666;
    margin-bottom: 1rem;
    font-size: 1rem;
}

.filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    padding: 0.5rem;
    border-radius: 4px;
    transition: background-color 0.2s;
}

label:hover {
    background-color: #f0f0f0;
}

input[type="checkbox"] {
    width: 16px;
    height: 16px;
}

.debug-info {
    padding: 1rem;
    color: #666;
    font-style: italic;
    text-align: center;
}

.filter-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
}

.clear-all-btn {
    padding: 0.3rem 0.8rem;
    font-size: 0.8rem;
    color: #666;
    background: none;
    border: 1px solid #ddd;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
}

.clear-all-btn:hover {
    background: #f0f0f0;
    color: #333;
}

.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
}

.count-badge {
    font-size: 0.8rem;
    color: #666;
    background: #f0f0f0;
    padding: 0.2rem 0.5rem;
    border-radius: 12px;
}

.filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.filter-group.chips {
    flex-direction: row;
    flex-wrap: wrap;
    gap: 0.5rem;
}

.chip {
    display: inline-flex;
    align-items: center;
    padding: 0.3rem 0.8rem;
    background: #f8f9fa;
    border: 1px solid #e9ecef;
    border-radius: 16px;
    cursor: pointer;
    transition: all 0.2s;
}

.chip.active {
    background: #e7f1ff;
    border-color: #4a90e2;
    color: #4a90e2;
}

.chip input[type="checkbox"] {
    display: none;
}

.checkbox-label {
    margin-left: 0.5rem;
}

label:hover {
    background-color: #f8f9fa;
}

.filter-section + .filter-section {
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 1px solid #eee;
}
</style>
