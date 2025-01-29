<script setup>
import { ref, onMounted } from 'vue';

const folders = ref([]);
const error = ref('');
const isExpanded = ref(true);
const currentPath = ref('/');
const canGoBack = ref(false);
const emit = defineEmits(['path-change', 'expand-change']);

// 添加props
const props = defineProps({
    initialPath: {  // 添加 initialPath prop
        type: String,
        default: '/'
    }
});

function toggleSidebar() {
    isExpanded.value = !isExpanded.value;
    emit('expand-change', isExpanded.value);
}

async function loadFolders(path = '') {
    try {
        const response = await fetch(`http://localhost:5000/folders?path=${encodeURIComponent(path)}`);
        const data = await response.json();
        
        if (data.error) {
            error.value = data.error;
        } else {
            folders.value = data.folders;
            currentPath.value = data.current_path;
            canGoBack.value = data.can_go_back;
            emit('path-change', data.current_path);  // 添加事件发送
        }
    } catch (err) {
        error.value = '加载失败';
        console.error('Error loading folders:', err);
    }
}

function enterFolder(folderName) {
    const newPath = currentPath.value === '/' 
        ? folderName 
        : `${currentPath.value}/${folderName}`;
    loadFolders(newPath);
}

function goBack() {
    const parentPath = currentPath.value.split('/').slice(0, -1).join('/');
    loadFolders(parentPath);
}

// 修改 onMounted
onMounted(() => {
    if (props.initialPath !== '/') {
        loadFolders(props.initialPath);
    } else {
        loadFolders();
    }
});
</script>

<template>
    <div class="folder-list" :class="{ 'collapsed': !isExpanded }">
        <button class="toggle-btn" @click="toggleSidebar">
            {{ isExpanded ? '◀' : '▶' }}
        </button>
        <div class="content" v-show="isExpanded">
            <h2>文件夹列表</h2>
            <div v-if="error" class="error">
                {{ error }}
            </div>
            <div v-else class="folders">
                <div v-if="canGoBack" 
                     class="folder-item back-item"
                     @click="goBack">
                    <span class="folder-icon">↩</span>
                    返回上一级
                </div>
                <div v-for="folder in folders" 
                     :key="folder" 
                     class="folder-item"
                     @click="enterFolder(folder)">
                    <span class="folder-icon">📁</span>
                    {{ folder }}
                </div>
            </div>
            <div class="current-path">
                当前路径: {{ currentPath }}
            </div>
        </div>
    </div>
</template>

<style scoped>
.folder-list {
    position: fixed;
    left: 0;
    top: 0;
    bottom: 6rem;
    background: white;
    width: 300px;
    box-shadow: 2px 0 5px rgba(0, 0, 0, 0.1);
    transition: width 0.3s ease;
    overflow-x: hidden;
    display: flex;
}

.folder-list.collapsed {
    width: 40px;
}

.toggle-btn {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translateY(-50%);
    background: #4a90e2;
    color: white;
    border: none;
    width: 24px;
    height: 40px;
    cursor: pointer;
    z-index: 2;
    border-radius: 0 4px 4px 0;
    padding: 0;
    font-size: 12px;
}

.toggle-btn:hover {
    background: #357abd;
}

.content {
    flex: 1;
    padding: 1rem;
    overflow-y: auto;
    min-width: 280px;
}

.folders {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 3rem;
}

.folder-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.8rem;
    background: #f8f9fa;
    border-radius: 6px;
    transition: all 0.2s;
    cursor: pointer;
}

.folder-item:hover {
    background: #e9ecef;
    transform: translateX(5px);
}

.error {
    color: #dc3545;
    padding: 1rem;
    background: #fee;
    border-radius: 8px;
    margin-top: 1rem;
}

h2 {
    color: #333;
    margin-bottom: 1rem;
    font-size: 1.2rem;
}

.folder-icon {
    font-size: 1.2rem;
}

.back-item {
    background-color: #edf2f7;
    border: 1px solid #e2e8f0;
}

.back-item:hover {
    background-color: #e2e8f0;
}

.current-path {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 1rem;
    background-color: #f8f9fa;
    border-top: 1px solid #e2e8f0;
    font-size: 0.9rem;
    color: #666;
    word-break: break-all;
}
</style>
