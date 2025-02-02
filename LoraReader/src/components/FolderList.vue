<script setup>
import { ref, onMounted } from 'vue';

const folders = ref([]);
const error = ref('');
const isExpanded = ref(true);
const currentPath = ref('/');
const canGoBack = ref(false);
const emit = defineEmits(['path-change', 'expand-change', 'view-mode-change']); // 添加新的事件
const dragOverFolder = ref(null);
const showAllLoras = ref(false);

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

function toggleViewMode() {
    showAllLoras.value = !showAllLoras.value;
    emit('view-mode-change', showAllLoras.value);
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

// 添加拖拽处理函数
async function handleDrop(event, targetFolder) {
    event.preventDefault();
    dragOverFolder.value = null; // 清除拖拽状态
    
    try {
        const data = JSON.parse(event.dataTransfer.getData('application/json'));
        if (data.type !== 'lora') return;

        const sourcePath = data.sourcePath || '';
        const targetPath = targetFolder === '..' ? 
            currentPath.value.split('/').slice(0, -1).join('/') : 
            currentPath.value === '/' ? targetFolder : `${currentPath.value}/${targetFolder}`;

        console.log('Moving LoRA:', {
            sourcePath,
            targetPath,
            loraName: data.data.base_name
        });

        const response = await fetch('http://localhost:5000/move-lora', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                sourcePath,
                targetPath,
                loraName: data.data.base_name
            })
        });

        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || '移动失败');
        }

        // 发出事件通知父组件刷新当前路径的内容
        emit('path-change', currentPath.value);
        
        // 如果成功，显示成功消息
        alert('文件移动成功！');

        // 成功后添加一个动画效果
        const targetElement = event.currentTarget;
        targetElement.classList.add('drop-success');
        setTimeout(() => {
            targetElement.classList.remove('drop-success');
        }, 1000);
        
        // 通知父组件刷新
        emit('path-change', currentPath.value);
    } catch (error) {
        // 错误时添加动画效果
        const targetElement = event.currentTarget;
        targetElement.classList.add('drop-error');
        setTimeout(() => {
            targetElement.classList.remove('drop-error');
        }, 1000);
        
        console.error('移动文件失败:', error);
        alert(error.message || '移动文件失败');
    }
}

function handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
}

function handleDragEnter(folder) {
    dragOverFolder.value = folder;
}

function handleDragLeave(e) {
    // 只有当鼠标真正离开元素（而不是进入子元素）时才清除状态
    if (!e.currentTarget.contains(e.relatedTarget)) {
        dragOverFolder.value = null;
    }
}
</script>

<template>
    <div class="folder-list" :class="{ 'collapsed': !isExpanded }">
        <button class="toggle-btn" @click="toggleSidebar">
            {{ isExpanded ? '◀' : '▶' }}
        </button>
        <div class="content" v-show="isExpanded">
            <!-- 添加新的按钮 -->
            <div class="view-mode-toggle">
                <button 
                    class="view-all-btn" 
                    :class="{ active: showAllLoras }"
                    @click="toggleViewMode"
                >
                    {{ showAllLoras ? '返回文件夹视图' : '查看所有 Lora' }}
                </button>
            </div>
            
            <!-- 现有的文件夹列表，在全局视图下隐藏 -->
            <template v-if="!showAllLoras">
                <h2>文件夹列表</h2>
                <div v-if="error" class="error">
                    {{ error }}
                </div>
                <div v-else class="folders">
                    <div v-if="canGoBack" 
                         class="folder-item back-item"
                         :class="{ 'drag-over': dragOverFolder === '..' }"
                         @click="goBack"
                         @dragover.prevent="handleDragOver"
                         @dragenter="handleDragEnter('..')"
                         @dragleave="handleDragLeave"
                         @drop="handleDrop($event, '..')">
                        <span class="folder-icon">↩</span>
                        返回上一级
                        <div class="drop-indicator" v-if="dragOverFolder === '..'">
                            <span class="arrow">⬆</span>
                            <span class="text">移动到上一级</span>
                        </div>
                    </div>
                    <div v-for="folder in folders" 
                         :key="folder" 
                         class="folder-item"
                         :class="{ 'drag-over': dragOverFolder === folder }"
                         @click="enterFolder(folder)"
                         @dragover.prevent="handleDragOver"
                         @dragenter="handleDragEnter(folder)"
                         @dragleave="handleDragLeave"
                         @drop="handleDrop($event, folder)">
                        <span class="folder-icon">📁</span>
                        {{ folder }}
                        <div class="drop-indicator" v-if="dragOverFolder === folder">
                            <span class="arrow">➜</span>
                            <span class="text">移动到此文件夹</span>
                        </div>
                    </div>
                </div>
                <div class="current-path">
                    当前路径: {{ currentPath }}
                </div>
            </template>
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
    position: relative;
    transition: all 0.3s ease;
}

.folder-item:hover {
    background: #e9ecef;
    transform: translateX(5px);
}

.folder-item.drag-over {
    transform: scale(1.02) translateX(10px);
    background: #e3f2fd;
    border: 2px dashed #1976d2;
    box-shadow: 0 0 10px rgba(25, 118, 210, 0.2);
}

.drop-indicator {
    position: absolute;
    right: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: #1976d2;
    font-size: 0.9rem;
    animation: fadeInRight 0.3s ease;
    pointer-events: none; /* 防止指示器干扰拖拽事件 */
}

@keyframes fadeInRight {
    from {
        opacity: 0;
        transform: translateX(-10px);
    }
    to {
        opacity: 1;
        transform: translateX(0);
    }
}

.drop-success {
    animation: successPulse 1s ease;
}

.drop-error {
    animation: errorShake 0.5s ease;
}

@keyframes successPulse {
    0% { background: #e3f2fd; }
    50% { background: #a5d6a7; }
    100% { background: #f8f9fa; }
}

@keyframes errorShake {
    0%, 100% { transform: translateX(0); }
    25% { transform: translateX(-5px); }
    75% { transform: translateX(5px); }
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

.view-mode-toggle {
    margin-bottom: 1rem;
    padding: 0.5rem;
    background: #f0f4f8;
    border-radius: 8px;
}

.view-all-btn {
    width: 100%;
    padding: 0.8rem;
    border: none;
    border-radius: 6px;
    background: white;
    color: #1976d2;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.view-all-btn:hover {
    background: #e3f2fd;
    transform: translateY(-1px);
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.1);
}

.view-all-btn.active {
    background: #1976d2;
    color: white;
}
</style>
