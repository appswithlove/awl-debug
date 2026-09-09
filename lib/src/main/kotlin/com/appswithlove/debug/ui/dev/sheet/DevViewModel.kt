package com.appswithlove.debug.ui.dev.sheet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.DevLogCollector
import com.appswithlove.debug.ui.dev.log.LogCollector.devLogCollector
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class DevViewModel(
    private val devStore: DevStore,
    private val logCollector: DevLogCollector = devLogCollector,
) : ViewModel() {

    private val pendingActions = MutableSharedFlow<DevAction>()
    private val isShown = MutableStateFlow(false)

    val state = combine(
        devStore.isDevToolActivated,
        devStore.isDevToolAlwaysActive,
        isShown,
    ) { active, isAlwaysActive, shown ->
        DevSheetState(
            isActive = active,
            isAlwaysActive = isAlwaysActive,
            isShown = shown,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DevSheetState())

    init {
        viewModelScope.launch {
            pendingActions.collect { action ->
                when (action) {
                    is DevAction.ActivateDevTool -> activateDevTool()
                    is DevAction.ShowDevSheet -> showDevSheet()
                }
            }
        }
    }

    private fun activateDevTool() {
        if (!state.value.isAlwaysActive) {
            viewModelScope.launch {
                devStore.setDevToolActivated(!state.value.isActive)
            }
        }
    }

    private fun showDevSheet(show: Boolean? = null) {
        val isActive = state.value.isActive
        val isAlwaysActive = state.value.isAlwaysActive
        if (!isActive && !isAlwaysActive) {
            isShown.value = false
            return
        }
        if (show != null) {
            isShown.value = show
        } else {
            isShown.value = !isShown.value
        }
    }

    fun setIsAlwaysActive(isAlwaysActive: Boolean) {
        viewModelScope.launch {
            devStore.setDevToolAlwaysActive(isAlwaysActive)
            if (isAlwaysActive) {
                devStore.setDevToolActivated(true)
            }
        }
    }

    fun submitAction(action: DevAction) {
        viewModelScope.launch {
            pendingActions.emit(action)
        }
    }

    fun setMaxLogSize(size: Int) {
        logCollector.setMaxSize(size)
    }

    fun setTrackLogs(track: Boolean) {
        logCollector.setTrackLogs(track)
    }
}
