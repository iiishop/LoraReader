<script setup>
import { ref, onMounted } from 'vue';

const folderPath = ref('');
const isEditing = ref(false);
const emit = defineEmits(['confirm']);

async function getCurrentPath() {
    try {
        const response = await fetch('http://localhost:5000/config');
        const data = await response.json();
        folderPath.value = data.lora_path || '';
    } catch (error) {
        console.error('Error getting current path:', error);
    }
}

async function openFolderSelector() {
    if (window.electron && window.electron.dialog) {
        window.electron.dialog.showOpenDialog({
            properties: ['openDirectory']
        }).then(result => {
            if (!result.canceled) {
                folderPath.value = result.filePaths[0];
            }
        });
    } else {
        try {
            const response = await fetch('http://localhost:5000/select-folder');
            const data = await response.json();
            if (data.path) {
                folderPath.value = data.path;
            }
        } catch (error) {
            console.error('Error selecting folder:', error);
        }
    }
}

function confirmSelection() {
    if (folderPath.value) {
        emit('confirm', folderPath.value);
        isEditing.value = false;
    }
}

function startEditing() {
    isEditing.value = true;
}

function cancelEditing() {
    getCurrentPath(); // 重置为当前路径
    isEditing.value = false;
}

onMounted(getCurrentPath);
</script>

<template>
    <div class="path-selector">
        <div class="input-group">
            <input 
                type="text" 
                v-model="folderPath" 
                placeholder="选择文件夹路径" 
                :readonly="!isEditing" 
                :class="{ 'editing': isEditing }"
            />
            <template v-if="!isEditing">
                <button class="edit-btn" @click="startEditing">
                    修改路径
                </button>
            </template>
            <template v-else>
                <div class="edit-buttons">
                    <button class="select-btn" @click="openFolderSelector">
                        选择文件夹
                    </button>
                    <button class="confirm-btn" @click="confirmSelection">
                        确认
                    </button>
                    <button class="cancel-btn" @click="cancelEditing">
                        取消
                    </button>
                </div>
            </template>
        </div>
    </div>
</template>

<style scoped>
.path-selector {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    background: white;
    padding: 1rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.input-group {
    display: flex;
    gap: 0.5rem;
    align-items: center;
}

input {
    flex: 1;
    padding: 0.8rem 1rem;
    border: 2px solid #e0e0e0;
    border-radius: 6px;
    font-size: 1rem;
    transition: all 0.2s;
    outline: none;
    background-color: #f8f9fa;
}

input.editing {
    border-color: #4a90e2;
    background-color: white;
}

input:not(.editing) {
    color: #666;
}

.edit-buttons {
    display: flex;
    gap: 0.5rem;
}

button {
    padding: 0.8rem 1.5rem;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.2s;
}

.edit-btn {
    background-color: #f0f0f0;
    color: #666;
}

.select-btn {
    background-color: #4a90e2;
    color: white;
}

.confirm-btn {
    background-color: #2ecc71;
    color: white;
}

.cancel-btn {
    background-color: #e74c3c;
    color: white;
}

button:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

button:active {
    transform: translateY(0);
}
</style>
