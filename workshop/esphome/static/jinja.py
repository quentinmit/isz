import ionit_plugin

@ionit_plugin.function
def necformat(low, high=None):
    if high is None:
        high = ~low & 0xFF
    return (high << 8) + low
