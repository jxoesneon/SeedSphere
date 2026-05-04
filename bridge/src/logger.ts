export type LogLevel = 'INFO' | 'WARNING' | 'ERROR' | 'DEBUG';

export class Logger {
  constructor(private name: string) {}

  private log(level: LogLevel, message: string, context?: any) {
    const timestamp = new Date().toISOString();
    let msg = `${timestamp} [${level}] [${this.name}] ${message}`;
    if (context) {
      msg += ` ${JSON.stringify(context)}`;
    }
    console.log(msg);
  }

  info(message: string, context?: any) {
    this.log('INFO', message, context);
  }

  warn(message: string, context?: any) {
    this.log('WARNING', message, context);
  }

  error(message: string, context?: any) {
    this.log('ERROR', message, context);
  }

  debug(message: string, context?: any) {
    this.log('DEBUG', message, context);
  }
}
