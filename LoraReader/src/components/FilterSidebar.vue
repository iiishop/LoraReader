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

// 从所有 lora 文件中提取唯一的 metadata 值
const uniqueVersions = computed(() => {
    const versions = new Set();
    props.loraFiles.forEach(lora => {
        const version = lora.metadata?.ss_base_model_version;
        if (version && version !== 'Unknown') {
            versions.add(version);
        }
    });
    return Array.from(versions).sort();
});

const uniqueDims = computed(() => {
    const dims = new Set();
    props.loraFiles.forEach(lora => {
        const dim = lora.metadata?.ss_network_dim;
        if (dim) {
            dims.add(dim);
        }
    });
    return Array.from(dims).sort((a, b) => Number(a) - Number(b));
});

// 添加调试输出 - 移到computed之后
watch(() => props.loraFiles, (newFiles) => {
    console.log('Received lora files:', newFiles);
    console.log('Found versions:', uniqueVersions.value);
    console.log('Found dims:', uniqueDims.value);
}, { immediate: true });

const emit = defineEmits(['expand-change', 'filter-change']);

// 筛选条件状态
const selectedVersions = ref(new Set());
const selectedDims = ref(new Set());

function toggleVersion(version) {
    if (selectedVersions.value.has(version)) {
        selectedVersions.value.delete(version);
    } else {
        selectedVersions.value.add(version);
    }
    emitFilterChange();
}

function toggleDim(dim) {
    if (selectedDims.value.has(dim)) {
        selectedDims.value.delete(dim);
    } else {
        selectedDims.value.add(dim);
    }
    emitFilterChange();
}

function emitFilterChange() {
    emit('filter-change', {
        versions: Array.from(selectedVersions.value),
        dims: Array.from(selectedDims.value)
    });
}

function toggleSidebar() {
    emit('expand-change', !props.isExpanded);
}
</script>

<template>
    <div class="filter-sidebar" :class="{ 'collapsed': !isExpanded }">
        <button class="toggle-btn" @click="toggleSidebar">
            {{ isExpanded ? '▶' : '◀' }}
        </button>
        <div class="content" v-show="isExpanded">
            <h2>筛选条件</h2>
            
            <!-- 添加调试输出 -->
            <div class="debug-info" v-if="loraFiles.length === 0">
                暂无可筛选的文件
            </div>
            
            <div v-if="uniqueVersions.length > 0" class="filter-section">
                <h3>版本 ({{ uniqueVersions.length }})</h3>
                <div class="filter-group">
                    <label v-for="version in uniqueVersions" :key="version">
                        <input 
                            type="checkbox" 
                            :checked="selectedVersions.has(version)"
                            @change="toggleVersion(version)"
                        >
                        SD {{ version }}
                    </label>
                </div>
            </div>
            
            <div v-if="uniqueDims.length > 0" class="filter-section">
                <h3>维度 ({{ uniqueDims.length }})</h3>
                <div class="filter-group">
                    <label v-for="dim in uniqueDims" :key="dim">
                        <input 
                            type="checkbox" 
                            :checked="selectedDims.has(dim)"
                            @change="toggleDim(dim)"
                        >
                        {{ dim }}
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
