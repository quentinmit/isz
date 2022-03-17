import ionit_plugin
import more_itertools

@ionit_plugin.function
def necformat(low, high=None):
    if high is None:
        high = ~low & 0xFF
    return (high << 8) + low

@ionit_plugin.function
def flatten(l):
    return list(more_itertools.collapse(l))
