type LogContext = Record<string, unknown>;

const serviceName = 'ocr-server';
const version = process.env.npm_package_version ?? '0.1.0';

const buildPayload = (level: string, message: string, context?: LogContext) => ({
  service: serviceName,
  version,
  level,
  message,
  timestamp: new Date().toISOString(),
  ...(context ?? {}),
});

const log = (level: string, message: string, context?: LogContext) => {
  console.log(JSON.stringify(buildPayload(level, message, context)));
};

export const logger = {
  info: (message: string, context?: LogContext) => log('info', message, context),
  warn: (message: string, context?: LogContext) => log('warn', message, context),
  error: (message: string, context?: LogContext) => log('error', message, context),
  debug: (message: string, context?: LogContext) => log('debug', message, context),
};
