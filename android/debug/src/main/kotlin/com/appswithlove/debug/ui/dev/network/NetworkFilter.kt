package com.appswithlove.debug.ui.dev.network

internal enum class StatusClass(val label: String) {
    Informational("1xx"),
    Success("2xx"),
    Redirection("3xx"),
    ClientError("4xx"),
    ServerError("5xx"),
    Failed("Failed");

    companion object {
        fun of(entry: NetworkEntry): StatusClass = when {
            entry.isFailed -> Failed
            entry.status < 200 -> Informational
            entry.status < 300 -> Success
            entry.status < 400 -> Redirection
            entry.status < 500 -> ClientError
            else -> ServerError
        }
    }
}

internal enum class NetworkSort(val label: String) {
    NewestFirst("Newest first"),
    OldestFirst("Oldest first"),
}

/**
 * Search plus filter groups. Groups store the values the user deselected, so hosts and methods that
 * appear later are shown by default.
 */
internal data class NetworkFilter(
    val query: String = "",
    val excludedMethods: Set<String> = emptySet(),
    val excludedStatusClasses: Set<StatusClass> = emptySet(),
    val excludedHosts: Set<String> = emptySet(),
) {
    fun matches(entry: NetworkEntry): Boolean =
        entry.method !in excludedMethods &&
            StatusClass.of(entry) !in excludedStatusClasses &&
            entry.host !in excludedHosts &&
            matchesQuery(entry)

    private fun matchesQuery(entry: NetworkEntry): Boolean {
        val query = query.trim()
        if (query.isEmpty()) return true
        return entry.url.contains(query, ignoreCase = true) ||
            entry.method.contains(query, ignoreCase = true) ||
            entry.status.toString().contains(query) ||
            (entry.isFailed && StatusClass.Failed.label.contains(query, ignoreCase = true))
    }

    /** Human-readable active filters, empty when everything is shown. */
    fun describe(): List<String> = buildList {
        if (query.isNotBlank()) add("Search: $query")
        if (excludedMethods.isNotEmpty()) add("Hidden methods: ${excludedMethods.sorted().joinToString()}")
        if (excludedStatusClasses.isNotEmpty()) {
            add("Hidden response codes: ${excludedStatusClasses.sorted().joinToString { it.label }}")
        }
        if (excludedHosts.isNotEmpty()) add("Hidden hosts: ${excludedHosts.sorted().joinToString()}")
    }
}

internal fun List<NetworkEntry>.filteredAndSorted(filter: NetworkFilter, sort: NetworkSort): List<NetworkEntry> {
    val filtered = filter(filter::matches)
    return when (sort) {
        NetworkSort.NewestFirst -> filtered.reversed()
        NetworkSort.OldestFirst -> filtered
    }
}

internal fun <T> Set<T>.toggle(value: T): Set<T> = if (value in this) this - value else this + value
