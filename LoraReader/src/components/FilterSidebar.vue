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
        alphas: new Set()
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
        }
    });

    return {
        versions: Array.from(result.versions).sort(),
        dims: Array.from(result.dims).sort((a, b) => Number(a) - Number(b)),
        alphas: Array.from(result.alphas).sort((a, b) => Number(a) - Number(b))
    };
});

// 选中的筛选条件
const selectedFilters = ref({
    versions: new Set(),
    dims: new Set(),
    alphas: new Set()
});

// 修改 emitFilterChange 函数添加更多日志
function emitFilterChange() {
    const filters = {
        versions: Array.from(selectedFilters.value.versions),
        dims: Array.from(selectedFilters.value.dims),
        alphas: Array.from(selectedFilters.value.alphas)
    };
    console.log('Emitting filters from FilterSidebar:', filters);
    emit('filter-change', filters);
}

// 添加 watch 以监控 loraFiles 变化时清空选择
watch(() => props.loraFiles, () => {
    selectedFilters.value = {
        versions: new Set(),
        dims: new Set(),
        alphas: new Set()
    };
    emitFilterChange();
}, { deep: true });

// 移除 toggleFilter 函数，改用 watch 监听 selectedFilters
watch(selectedFilters, (newVal) => {
    emitFilterChange();
}, { deep: true });

</script>

<template>
    <div class="filter-sidebar" :class="{ 'collapsed': !isExpanded }">
        <button class="toggle-btn" @click="$emit('expand-change', !isExpanded)">
            {{ isExpanded ? '▶' : '◀' }}
        </button>
        
        <div class="content" v-if="isExpanded">
            <h2>筛选</h2>
            
            <!-- SD 版本筛选 -->
            <div class="filter-section" v-if="metadata.versions.length">
                <h3>SD 版本 ({{ metadata.versions.length }})</h3>
                <div class="filter-group">
                    <label v-for="version in metadata.versions" :key="version">
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.versions"
                            :value="version"
                        >
                        {{ version }}
                    </label>
                </div>
            </div>
            
            <!-- 维度筛选 -->
            <div class="filter-section" v-if="metadata.dims.length">
                <h3>维度 ({{ metadata.dims.length }})</h3>
                <div class="filter-group">
                    <label v-for="dim in metadata.dims" :key="dim">
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.dims"
                            :value="dim"
                        >
                        {{ dim }}
                    </label>
                </div>
            </div>
            
            <!-- Alpha 值筛选 -->
            <div class="filter-section" v-if="metadata.alphas.length">
                <h3>Alpha 值 ({{ metadata.alphas.length }})</h3>
                <div class="filter-group">
                    <label v-for="alpha in metadata.alphas" :key="alpha">
                        <input 
                            type="checkbox"
                            v-model="selectedFilters.alphas"
                            :value="alpha"
                        >
                        {{ alpha }}
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
    bottom: 0;
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
</style>
