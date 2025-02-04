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
            // 如果有 Illustrious 兼容的 LoRA，添加到基础模型列表中
            if (lora.config?.works_in_illustrious) {
                result.baseModels.add('SDXL-Illustrious');
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

// 添加折叠状态控制
const collapsedSections = ref({
    baseModels: false,
    versions: true,
    dims: true,
    alphas: true
});

function toggleSection(section) {
    collapsedSections.value[section] = !collapsedSections.value[section];
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
                    class="clear-all-btn" @click="clearAllFilters">
                    清除全部
                </button>
            </div>

            <!-- 基础模型筛选（默认展开） -->
            <div class="filter-section">
                <div class="section-header clickable" @click="toggleSection('baseModels')">
                    <div class="header-left">
                        <h3>基础模型</h3>
                        <span class="count-badge" v-if="filterCounts.baseModels">
                            {{ filterCounts.baseModels }}/{{ metadata.baseModels.length }}
                        </span>
                    </div>
                    <span class="collapse-icon">{{ collapsedSections.baseModels ? '▼' : '▲' }}</span>
                </div>
                <div class="filter-content" v-show="!collapsedSections.baseModels">
                    <div class="filter-grid">
                        <label v-for="model in metadata.baseModels" :key="model" class="grid-item">
                            <input type="checkbox" :value="model" :checked="selectedFilters.baseModels.has(model)"
                                @change="e => {
                                    if (e.target.checked) {
                                        selectedFilters.baseModels.add(model)
                                    } else {
                                        selectedFilters.baseModels.delete(model)
                                    }
                                }">
                            <span class="checkbox-label">{{ model }}</span>
                        </label>
                    </div>
                </div>
            </div>

            <!-- 其他筛选项（默认折叠） -->
            <div v-for="(items, type) in {
                versions: { title: 'SD 版本', data: metadata.versions },
                dims: { title: '维度', data: metadata.dims },
                alphas: { title: 'Alpha 值', data: metadata.alphas }
            }" :key="type" class="filter-section">
                <div class="section-header clickable" @click="toggleSection(type)">
                    <div class="header-left">
                        <h3>{{ items.title }}</h3>
                        <span class="count-badge" v-if="filterCounts[type]">
                            {{ filterCounts[type] }}/{{ items.data.length }}
                        </span>
                    </div>
                    <span class="collapse-icon">{{ collapsedSections[type] ? '▼' : '▲' }}</span>
                </div>
                <div class="filter-content" v-show="!collapsedSections[type]">
                    <div class="filter-grid">
                        <label v-for="item in items.data" :key="item" class="grid-item">
                            <input type="checkbox" v-model="selectedFilters[type]" :value="item">
                            <span class="checkbox-label">{{ item }}</span>
                        </label>
                    </div>
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
    padding-top: 4rem;
    /* 为顶部搜索框留出空间 */
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

.filter-section+.filter-section {
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 1px solid #eee;
}

.section-header.clickable {
    cursor: pointer;
    user-select: none;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem;
    background: #f8f9fa;
    border-radius: 6px;
    margin-bottom: 0.5rem;
}

.section-header.clickable:hover {
    background: #e9ecef;
}

.header-left {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.collapse-icon {
    color: #666;
    transition: transform 0.3s;
}

.filter-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 0.5rem;
    padding: 0.5rem;
}

.grid-item {
    padding: 0.3rem;
    border-radius: 4px;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: #f8f9fa;
}

.grid-item:hover {
    background: #e9ecef;
}

.filter-content {
    max-height: 300px;
    overflow-y: auto;
    transition: all 0.3s ease;
    margin-bottom: 1rem;
}
</style>
