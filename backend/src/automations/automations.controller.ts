import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Request,
} from '@nestjs/common';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';
import type { ControllerResponse } from 'src/config/config.interface';
import { AutomationsService } from './automations.service';
import { CreateAutomationDto } from './dto/create-automation.dto';

@Controller('automations')
export class AutomationsController {
  constructor(private readonly automationsService: AutomationsService) {}

  @Get()
  async findAll(
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const automations = await this.automationsService.findAll(req.user.sub);
    return {
      success: true,
      message: 'Automations fetched',
      data: { automations },
    };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Body() dto: CreateAutomationDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const automation = await this.automationsService.create(req.user.sub, dto);
    return {
      success: true,
      message: 'Automation created',
      data: { automation },
    };
  }

  @Patch(':id/toggle')
  async toggle(
    @Param('id') id: string,
    @Body('isActive') isActive: boolean,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const automation = await this.automationsService.toggleActive(
      id,
      req.user.sub,
      isActive,
    );
    return {
      success: true,
      message: 'Automation updated',
      data: { automation },
    };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<void> {
    await this.automationsService.delete(id, req.user.sub);
  }
}
