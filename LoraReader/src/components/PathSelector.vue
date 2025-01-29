<script setup>
import { ref } from 'vue';

const folderPath = ref('');
const emit = defineEmits(['confirm']);  // 确保在最上面定义 emit

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
    if (folderPath.value) {  // 添加路径检查
        console.log('Confirming path:', folderPath.value);
        emit('confirm', folderPath.value);
    }
}
</script>

<template>
    <div class="path-selector">
        <input type="text" v-model="folderPath" placeholder="选择文件夹路径" readonly />
        <div class="buttons">
            <button class="select-btn" @click="openFolderSelector">选择文件夹</button>
            <button class="confirm-btn" @click="confirmSelection">确认</button>
        </div>
    </div>
</template>

<style scoped>
.path-selector {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

/* ...其他样式保持不变... */

.path-selector:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
}

input {
    width: 100%;
    padding: 0.8rem 1rem;
    margin-bottom: 1rem;
    border: 2px solid #e0e0e0;
    border-radius: 6px;
    font-size: 1rem;
    transition: border-color 0.2s;
    outline: none;
    background-color: #f8f9fa;
}

input:focus {
    border-color: #4a90e2;
}

.buttons {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
}

button {
    padding: 0.8rem 1.5rem;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    cursor: pointer;
    transition: transform 0.1s, opacity 0.2s;
}

button:active {
    transform: scale(0.98);
}

.select-btn {
    background-color: #4a90e2;
    color: white;
}

.select-btn:hover {
    background-color: #357abd;
}

.confirm-btn {
    background-color: #2ecc71;
    color: white;
}

.confirm-btn:hover {
    background-color: #27ae60;
}

@media (max-width: 768px) {
    .input-group {
        padding: 1.5rem;
    }

    .buttons {
        flex-direction: column;
    }

    button {
        width: 100%;
    }
}
</style>
