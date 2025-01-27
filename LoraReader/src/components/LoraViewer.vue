<script setup>
import { ref, watch, computed } from 'vue';
import { gsap } from 'gsap';
import { TransitionGroup } from 'vue';

const props = defineProps({
    currentPath: {
        type: String,
        default: '/'
    },
    isExpanded: {  // 添加新的 prop
        type: Boolean,
        default: true
    }
});

const loraFiles = ref([]);
const error = ref('');
const loading = ref(false);
const searchQuery = ref('');

const filteredLoraFiles = computed(() => {
    if (!searchQuery.value) return loraFiles.value;
    const query = searchQuery.value.toLowerCase();
    return loraFiles.value.filter(lora => 
        lora.base_name.toLowerCase().includes(query)
    );
});

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
            loraFiles.value = data.lora_files;
        }
    } catch (err) {
        error.value = `加载失败: ${err.message}`;
        console.error('Error loading lora files:', err);
    } finally {
        loading.value = false;
    }
}

watch(() => props.currentPath, (newPath) => {
    loadLoraFiles(newPath);
}, { immediate: true });
</script>

<template>
    <div class="lora-viewer" :class="{ 'list-collapsed': !isExpanded }">
        <div class="search-container">
            <input 
                type="text" 
                v-model="searchQuery"
                placeholder="搜索 Lora..."
                class="search-input"
            />
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
                 class="lora-card">
                <div class="preview">
                    <img v-if="lora.has_preview" :src="`http://localhost:5000${lora.preview_path}`" :alt="lora.name" />
                    <div v-else class="no-preview">
                        无预览图
                    </div>
                </div>
                <div class="info">
                    <div class="name">{{ lora.base_name }}</div>
                    <div class="metadata" v-if="lora.metadata">
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
    </div>
</template>

<style scoped>
.lora-viewer {
    padding-top: 4rem;  /* 为固定定位的搜索框留出空间 */
    overflow-y: auto;
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

.search-container {
    position: fixed;
    top: 0;
    left: 300px;  /* 与侧边栏宽度对应 */
    right: 0;
    z-index: 100;
    background: white;
    padding: 1rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    display: flex;
    justify-content: center;
    transition: left 0.3s ease;  /* 添加过渡效果 */
}

.list-collapsed .search-container {
    left: 40px;  /* 当侧边栏收起时调整位置 */
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
</style>
