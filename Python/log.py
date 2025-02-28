import logging
import coloredlogs
import sys

logging.basicConfig()
logger = logging.getLogger(name='logger')
coloredlogs.install(logger=logger)
logger.propagate = False
coloredFormatter = coloredlogs.ColoredFormatter(
    fmt='%(asctime)s %(message)s',
    level_styles=dict(
        debug=dict(color='white'),
        info=dict(color='green'),
        warning=dict(color='yellow'),
        error=dict(color='red', bright=True),
        critical=dict(color='red', bold=True),
    ),
    field_styles=dict(
        asctime=dict(color='white')
    )
)
ch = logging.StreamHandler(stream=sys.stdout)
ch.setFormatter(fmt=coloredFormatter)
logger.addHandler(hdlr=ch)
logger.setLevel(level=logging.INFO)

class Log:
    def __init__(self):
        pass

    @staticmethod
    def d(msg, *args, **kwargs):
        logger.debug(msg, *args, **kwargs)

    @staticmethod
    def i(msg, *args, **kwargs):
        logger.info(msg, *args, **kwargs)

    @staticmethod
    def w(msg, *args, **kwargs):
        logger.warning(msg, *args, **kwargs)

    @staticmethod
    def e(msg, *args, **kwargs):
        logger.error(msg, *args, **kwargs)

if __name__ == '__main__':
    Log.d("This is a debug log.")
    Log.i("This is a info log.")
    Log.w("This is a warning log.")
    Log.e("This is a error log.")