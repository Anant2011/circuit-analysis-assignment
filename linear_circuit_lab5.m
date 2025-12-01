function linear_circuit_lab()


%% Initial app state
S.components    = {};
S.wires         = {};
S.mode          = 'select';
S.gridSnap      = 8;     % distance tolerance for merging nodes / picking
S.gridStep      = 20;    % SNAP-TO-GRID step (pixels)
S.lastClick     = [];
S.groundCoord   = [];
S.simResult     = [];
S.selectedIndex = [];
S.projectFile   = '';

%% Create figure and axes (store explicit handles)
fig = figure('Name','Linear Circuit Lab','NumberTitle','off','Color',[0 0 0], ...
    'Units','pixels','Position',[200 120 1200 700], 'MenuBar','none');

ax = axes('Parent',fig,'Position',[0.02 0.03 0.78 0.73]);
hold(ax,'on'); axis(ax,'equal');
axis(ax,[0 1000 0 600]); set(ax,'YDir','reverse');
ax.Color = [0 0 0];
title(ax,'Canvas: Place components and wires here'); xlabel(ax,'X'); ylabel(ax,'Y');

% store handles in S
S.fig = fig; S.ax = ax; S.handles = struct();

%% Toolbar (left/top)
uicontrol(fig,'Style','text','String','Tools','Units','normalized', ...
    'Position',[0.01 0.94 0.04 0.05],'FontWeight','bold','ForegroundColor',[1 1 1], ...
    'BackgroundColor',[0 0 0]);

btnPosX = 0.01; btnW = 0.08; btnH = 0.055; gap = 0.01;
mkBtn(@() setMode('select')   ,'Select/Move',     btnPosX+0*(btnW+gap));
mkBtn(@() setMode('add_R')    ,'Add Resistor',    btnPosX+1*(btnW+gap));
mkBtn(@() setMode('add_C')    ,'Add Capacitor',   btnPosX+2*(btnW+gap));
mkBtn(@() setMode('add_L')    ,'Add Inductor',    btnPosX+3*(btnW+gap));
mkBtn(@() setMode('add_V')    ,'Add Vsrc',        btnPosX+4*(btnW+gap));
mkBtn(@() setMode('add_I')    ,'Add Isrc',        btnPosX+5*(btnW+gap));
mkBtn(@() setMode('wire')     ,'Add Wire',        btnPosX+6*(btnW+gap));
mkBtn(@() setMode('set_ground'),'Set Ground',     btnPosX+7*(btnW+gap));
mkBtn(@() setMode('delete')   ,'Delete',          btnPosX+8*(btnW+gap));

% simulation controls
mkBtn(@() runSimulation('dc')  ,'Simulate DC',        0.01, 0.80, 0.12);
mkBtn(@() runSimulation('tran'),'Simulate Transient', 0.14, 0.80, 0.18);
mkBtn(@() printNetlist()       ,'Print Netlist',      0.33, 0.80, 0.11);
mkBtn(@() saveProject()        ,'Save Project',       0.45, 0.80, 0.12);
mkBtn(@() loadProject()        ,'Load Project',       0.58, 0.80, 0.12);
mkBtn(@() clearAll()           ,'Clear All',          0.71, 0.80, 0.12);

% Info text
uicontrol(fig,'Style','text','String', ...
    'Click two points to place component. For wires: click multiple points, finish with right-click or double-click.', ...
    'Units','normalized','Position',[0.01 0.76 0.7 0.03], ...
    'HorizontalAlignment','left','ForegroundColor',[1 1 1], ...
    'BackgroundColor',[0 0 0]);

% Inspector (right)
uicontrol(fig,'Style','text','String','Inspector','Units','normalized', ...
    'Position',[0.83 0.94 0.14 0.04],'FontWeight','bold', ...
    'ForegroundColor',[1 1 1],'BackgroundColor',[0 0 0]);
uicontrol(fig,'Style','text','String','Selected:','Units','normalized', ...
    'Position',[0.83 0.89 0.07 0.03],'HorizontalAlignment','left', ...
    'ForegroundColor',[1 1 1],'BackgroundColor',[0 0 0]);

S.handles.hSel = uicontrol(fig,'Style','text','String','(none)','Units','normalized', ...
    'Position',[0.90 0.89 0.07 0.03],'HorizontalAlignment','left', ...
    'Tag','selLabel','ForegroundColor',[1 1 1],'BackgroundColor',[0 0 0]);

uicontrol(fig,'Style','text','String','Name','Units','normalized', ...
    'Position',[0.83 0.84 0.05 0.03],'HorizontalAlignment','left', ...
    'ForegroundColor',[1 1 1],'BackgroundColor',[0 0 0]);
S.handles.hName = uicontrol(fig,'Style','edit','String','','Units','normalized', ...
    'Position',[0.88 0.84 0.09 0.035],'Callback',@(h,~) setName(h));

uicontrol(fig,'Style','text','String','Value','Units','normalized', ...
    'Position',[0.83 0.80 0.05 0.03],'HorizontalAlignment','left', ...
    'ForegroundColor',[1 1 1],'BackgroundColor',[0 0 0]);
S.handles.hValue = uicontrol(fig,'Style','edit','String','','Units','normalized', ...
    'Position',[0.88 0.80 0.09 0.035],'Callback',@(h,~) setValue(h));

mkBtn(@() setMode('probe_node')  ,'Probe Node',   0.83, 0.73, 0.14);
mkBtn(@() setMode('probe_branch'),'Probe Branch', 0.83, 0.66, 0.14);

% Mouse/keyboard callbacks
set(fig,'WindowButtonDownFcn',@mouseDown);
set(fig,'WindowButtonUpFcn',  @mouseUp);
set(fig,'WindowButtonMotionFcn',@mouseMove);
set(fig,'KeyPressFcn',        @keyPress);

% store initial state on figure
setappdata(fig,'S',S);

% draw initial grid
drawGrid();

%% === Nested helper functions ===========================================
    function mkBtn(cb,label,x,posY,w)
        if nargin<5, w = btnW; end
        if nargin<4, posY = 0.88; end
        uicontrol(fig,'Style','pushbutton','String',label,'Units','normalized', ...
            'Position',[x posY w btnH],'Callback',@(~,~) cb());
    end

    function setMode(m)
        S = getappdata(fig,'S');
        S.mode = m;
        S.lastClick = [];
        S.selectedIndex = [];
        setappdata(fig,'S',S);
        updateInspector();
        title(ax,['Mode: ' m]);
    end

    function drawGrid()
        S = getappdata(fig,'S');
        step = S.gridStep;
        [X,Y] = meshgrid(0:step:1000, 0:step:600);
        scatter(ax,X(:),Y(:),2,[0.4 0.4 0.4],'.','HitTest','off'); % faint grid
    end

    function p = getClickPoint()
        C = get(ax,'CurrentPoint');
        p = C(1,1:2);
    end

    function pOut = snapToGrid(pIn)
        S = getappdata(fig,'S');
        h = S.gridStep;
        pOut = round(pIn./h)*h;
    end

    function mouseDown(~,~)
        S = getappdata(fig,'S');
        p = getClickPoint();
        p = snapToGrid(p);
        clickType = get(fig,'SelectionType'); % 'normal', 'alt', 'open'

        switch S.mode
            case {'add_R','add_C','add_L','add_V','add_I'}
                if isempty(S.lastClick)
                    S.lastClick = p;
                    setappdata(fig,'S',S);
                    return;
                else
                    p1 = S.lastClick; p2 = p;
                    val = askValueForMode(S.mode);
                    if isempty(val)
                        S.lastClick = []; setappdata(fig,'S',S); return;
                    end
                    addComponentFromMode(S.mode,p1,p2,val);
                    S.lastClick = []; setappdata(fig,'S',S);
                end

            case 'wire'
                if isempty(S.lastClick)
                    S.lastClick = {p};
                    setappdata(fig,'S',S); return;
                else
                    pts = S.lastClick;
                    pts{end+1} = p;
                    S.lastClick = pts;
                    setappdata(fig,'S',S);
                    if strcmp(clickType,'alt') || strcmp(clickType,'open')
                        ptsArr = cell2mat(pts');
                        addWire(ptsArr);
                        S.lastClick = []; setappdata(fig,'S',S);
                    end
                end

            case 'select'
                idx = pickComponent(p);
                if ~isempty(idx)
                    S.selectedIndex = idx;
                else
                    S.selectedIndex = [];
                end
                setappdata(fig,'S',S);
                updateInspector();

            case 'set_ground'
                nodeCoord = pickNodeCoordNear(p);
                if isempty(nodeCoord)
                    warndlg('No node nearby to set ground. Place components/wires first.','Set Ground');
                else
                    S.groundCoord = nodeCoord;
                    setappdata(fig,'S',S);
                    plotGround(nodeCoord);
                end

            case 'delete'
                idx = pickComponent(p);
                if ~isempty(idx)
                    deleteComponent(idx);
                else
                    widx = pickWireNear(p);
                    if ~isempty(widx), deleteWire(widx); end
                end

            case 'probe_node'
                if isempty(S.simResult)
                    warndlg('Run a simulation first (DC or Transient).','Probe');
                else
                    nodeCoord = pickNodeCoordNear(p);
                    if isempty(nodeCoord)
                        warndlg('No node near click.');
                    else
                        probeNode(nodeCoord);
                    end
                end

            case 'probe_branch'
                if isempty(S.simResult)
                    warndlg('Run a simulation first (DC or Transient).','Probe');
                else
                    bidx = pickBranchNear(p);
                    if isempty(bidx)
                        warndlg('No branch near click.');
                    else
                        probeBranch(bidx);
                    end
                end
        end
    end

    function mouseUp(~,~)
        S = getappdata(fig,'S');
        if isfield(S,'dragging') && S.dragging
            S.dragging = false;
            setappdata(fig,'S',S);
        end
    end

    function mouseMove(~,~)
        getappdata(fig,'S'); %#ok<NASGU>
    end

    function keyPress(~,ev)
        S = getappdata(fig,'S');
        if strcmp(ev.Key,'delete') && ~isempty(S.selectedIndex)
            deleteComponent(S.selectedIndex);
            S.selectedIndex = [];
            setappdata(fig,'S',S);
            updateInspector();
        end
    end

%% Component & wire operations
    function addComponentFromMode(mode,p1,p2,val)
        S = getappdata(fig,'S');
        switch mode
            case 'add_R', type = 'R'; name = sprintf('R%d',numel(S.components)+1);
            case 'add_C', type = 'C'; name = sprintf('C%d',numel(S.components)+1);
            case 'add_L', type = 'L'; name = sprintf('L%d',numel(S.components)+1);
            case 'add_V', type = 'V'; name = sprintf('V%d',numel(S.components)+1);
            case 'add_I', type = 'I'; name = sprintf('I%d',numel(S.components)+1);
            otherwise, return;
        end
        hLine = line(ax,[p1(1) p2(1)],[p1(2) p2(2)], ...
            'LineWidth',3,'Color',[1 1 1]);
        hTxt  = text(ax,(p1(1)+p2(1))/2,(p1(2)+p2(2))/2, ...
            sprintf('%s\n%g',type,val), ...
            'HorizontalAlignment','center', ...
            'Color',[1 1 1],'FontSize',8);
        comp = struct('type',type,'p1',p1,'p2',p2,'value',val,'name',name,'handles',[hLine hTxt]);
        S.components{end+1} = comp;
        setappdata(fig,'S',S);
    end

    function addWire(pts)
        S = getappdata(fig,'S');
        h = line(ax,pts(:,1),pts(:,2),'Color',[1 1 1],'LineWidth',1);
        S.wires{end+1} = struct('pts',pts,'handle',h);
        setappdata(fig,'S',S);
    end

    function deleteComponent(idx)
        S = getappdata(fig,'S');
        if idx>0 && idx<=numel(S.components)
            try delete(S.components{idx}.handles); catch, end
            S.components(idx) = [];
            setappdata(fig,'S',S);
            updateInspector();
        end
    end

    function deleteWire(widx)
        S = getappdata(fig,'S');
        if widx>0 && widx<=numel(S.wires)
            try delete(S.wires{widx}.handle); catch, end
            S.wires(widx) = [];
            setappdata(fig,'S',S);
        end
    end

    function idx = pickComponent(pt)
        S = getappdata(fig,'S');
        idx = [];
        best = inf; bi = [];
        for k=1:numel(S.components)
            c = S.components{k};
            d = pointToSegmentDistance(pt, c.p1, c.p2);
            if d < S.gridSnap && d < best
                best = d; bi = k;
            end
        end
        if ~isempty(bi), idx = bi; end
    end

    function bidx = pickBranchNear(pt)
        S = getappdata(fig,'S');
        bidx = [];
        best = inf; bi = [];
        for k=1:numel(S.components)
            c = S.components{k};
            d = pointToSegmentDistance(pt, c.p1, c.p2);
            if d < S.gridSnap && d < best
                best = d; bi = k;
            end
        end
        if ~isempty(bi)
            bidx = bi; return;
        end
        for w=1:numel(S.wires)
            pts = S.wires{w}.pts;
            for j=1:size(pts,1)-1
                d = pointToSegmentDistance(pt, pts(j,:), pts(j+1,:));
                if d < S.gridSnap && d < best
                    best = d; bi = numel(S.components) + (w-1) + 1;
                end
            end
        end
        if ~isempty(bi), bidx = bi; end
    end

    function nodeCoord = pickNodeCoordNear(pt)
        S = getappdata(fig,'S');

        nPts = 2 * numel(S.components);
        for k = 1:numel(S.wires)
            nPts = nPts + size(S.wires{k}.pts,1);
        end
        if nPts == 0
            nodeCoord = [];
            return;
        end

        ptsCell = cell(nPts,1);
        idx = 1;
        for k = 1:numel(S.components)
            c = S.components{k};
            ptsCell{idx} = c.p1; idx = idx + 1;
            ptsCell{idx} = c.p2; idx = idx + 1;
        end
        for k = 1:numel(S.wires)
            wpts = S.wires{k}.pts;
            for j = 1:size(wpts,1)
                ptsCell{idx} = wpts(j,:);
                idx = idx + 1;
            end
        end
        pts = cell2mat(ptsCell);

        d = sqrt((pts(:,1)-pt(1)).^2 + (pts(:,2)-pt(2)).^2);
        [mn, idmin] = min(d);
        if mn <= S.gridSnap
            nodeCoord = pts(idmin,:);
        else
            nodeCoord = [];
        end
    end

    function widx = pickWireNear(pt)
        S = getappdata(fig,'S');
        widx = [];
        for w=1:numel(S.wires)
            pts = S.wires{w}.pts;
            for j=1:size(pts,1)-1
                d = pointToSegmentDistance(pt, pts(j,:), pts(j+1,:));
                if d < S.gridSnap
                    widx = w; return;
                end
            end
        end
    end

    function plotGround(coord)
        h = findobj(ax,'Tag','groundMarker');
        if ~isempty(h), delete(h); end
        scatter(ax, coord(1), coord(2), 80, 'filled', ...
            'MarkerFaceColor',[0 1 0], 'Tag','groundMarker');
    end

    function updateInspector()
        S = getappdata(fig,'S');
        if isempty(S.selectedIndex)
            set(S.handles.hSel,'String','(none)');
            set(S.handles.hName,'String','');
            set(S.handles.hValue,'String','');
        else
            idx = S.selectedIndex;
            comp = S.components{idx};
            set(S.handles.hSel,'String', sprintf('%s (idx %d)', comp.name, idx));
            set(S.handles.hName,'String', comp.name);
            set(S.handles.hValue,'String', num2str(comp.value));
        end
    end

    function setName(h)
        S = getappdata(fig,'S');
        if isempty(S.selectedIndex), return; end
        newName = get(h,'String');
        S.components{S.selectedIndex}.name = newName;
        setappdata(fig,'S',S);
    end

    function setValue(h)
        S = getappdata(fig,'S');
        if isempty(S.selectedIndex), return; end
        val = str2double(get(h,'String'));
        if isnan(val)
            warndlg('Value must be numeric','Value'); return;
        end
        S.components{S.selectedIndex}.value = val;
        ch = S.components{S.selectedIndex}.handles;
        try
            set(ch(2),'String', sprintf('%s\n%g', S.components{S.selectedIndex}.type, val));
        catch
        end
        setappdata(fig,'S',S);
    end

%% Utils
    function d = pointToSegmentDistance(p,a,b)
        v = b - a; w = p - a;
        c1 = dot(w,v);
        if c1 <= 0, d = norm(p - a); return; end
        c2 = dot(v,v);
        if c2 <= c1, d = norm(p - b); return; end
        t = c1 / c2; proj = a + t * v; d = norm(p - proj);
    end

    function val = askValueForMode(mode)
        switch mode
            case 'add_R', prompt = 'Resistance (ohms)'; def = '100';
            case 'add_C', prompt = 'Capacitance (F)';   def = '1e-6';
            case 'add_L', prompt = 'Inductance (H)';    def = '1e-3';
            case 'add_V', prompt = 'Voltage (V)';       def = '10';
            case 'add_I', prompt = 'Current (A)';       def = '0.01';
            otherwise,    prompt = 'Value';             def = '1';
        end
        answer = inputdlg(prompt,'Component value',1,{def});
        if isempty(answer)
            val = [];
        else
            val = str2double(answer{1});
        end
    end

%% Simulation (MNA) - DC & Transient
    function runSimulation(kind)
        S = getappdata(fig,'S');
        if isempty(S.components) && isempty(S.wires)
            errordlg('No elements to simulate.','Simulate'); return;
        end

        % collect all endpoints / wire vertices
        nPts = 2 * numel(S.components);
        for kk = 1:numel(S.wires)
            nPts = nPts + size(S.wires{kk}.pts,1);
        end
        if nPts == 0
            errordlg('No nodes found.','Simulate'); return;
        end
        ptsCell = cell(nPts,1); pidx = 1;
        for k = 1:numel(S.components)
            c = S.components{k};
            ptsCell{pidx} = c.p1; pidx = pidx + 1;
            ptsCell{pidx} = c.p2; pidx = pidx + 1;
        end
        for k = 1:numel(S.wires)
            wpts = S.wires{k}.pts;
            for j = 1:size(wpts,1)
                ptsCell{pidx} = wpts(j,:); pidx = pidx + 1;
            end
        end
        pts = cell2mat(ptsCell);

        [nodes, ~] = mergePoints(pts, S.gridSnap);

        function ni = coordToNodeIndex(coord)
            d = sqrt((nodes(:,1)-coord(1)).^2 + (nodes(:,2)-coord(2)).^2);
            [~, ni] = min(d);
        end

        % build branches
        nb = numel(S.components);
        for ww = 1:numel(S.wires)
            nb = nb + max(0, size(S.wires{ww}.pts,1)-1);
        end
        prototype = struct('type','','n1',0,'n2',0,'value',0,'name','');
        branches = repmat(prototype, max(nb,1), 1);
        bi = 1;
        for k = 1:numel(S.components)
            c = S.components{k};
            b.type  = c.type;
            b.n1    = coordToNodeIndex(c.p1);
            b.n2    = coordToNodeIndex(c.p2);
            b.value = c.value;
            b.name  = c.name;
            branches(bi) = b; bi = bi + 1;
        end
        for w = 1:numel(S.wires)
            ptsw = S.wires{w}.pts;
            nseg = max(0,size(ptsw,1)-1);
            for j = 1:nseg
                b.type  = 'W';
                b.n1    = coordToNodeIndex(ptsw(j,:));
                b.n2    = coordToNodeIndex(ptsw(j+1,:));
                b.value = 0;
                b.name  = sprintf('W%d',w);
                branches(bi) = b; bi = bi + 1;
            end
        end
        if bi <= numel(branches), branches(bi:end) = []; end

        % ground
        if isempty(S.groundCoord)
            choice = questdlg('No ground chosen. Choose ground automatically?','Ground','Auto','Pick','Cancel','Auto');
            if strcmp(choice,'Cancel'), return; end
            if strcmp(choice,'Pick')
                errordlg('Use "Set Ground" and click on a node.','Ground'); return;
            end
            [~, gidx] = min(nodes(:,2)); groundNode = gidx;
        else
            groundNode = coordToNodeIndex(S.groundCoord);
        end

        Nnodes = size(nodes,1);
        vsrc_branches = find(arrayfun(@(b) strcmp(b.type,'V'), branches));
        M = numel(vsrc_branches);
        nvar = (Nnodes - 1) + M;
        G = zeros(nvar); Ivec = zeros(nvar,1);

        nodeEq = zeros(Nnodes,1); eq = 0;
        for ni = 1:Nnodes
            if ni == groundNode
                nodeEq(ni) = 0;
            else
                eq = eq + 1; nodeEq(ni) = eq;
            end
        end

        vmap = containers.Map('KeyType','double','ValueType','double');
        for k = 1:M
            bidx = vsrc_branches(k);
            vmap(bidx) = (Nnodes - 1) + k;
        end

        % DC stamping
        for bidx = 1:numel(branches)
            br = branches(bidx); n1 = br.n1; n2 = br.n2;
            switch br.type
                case 'R'
                    g = 1.0 / br.value;
                    if nodeEq(n1)>0, G(nodeEq(n1),nodeEq(n1)) = G(nodeEq(n1),nodeEq(n1)) + g; end
                    if nodeEq(n2)>0, G(nodeEq(n2),nodeEq(n2)) = G(nodeEq(n2),nodeEq(n2)) + g; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        G(nodeEq(n1),nodeEq(n2)) = G(nodeEq(n1),nodeEq(n2)) - g;
                        G(nodeEq(n2),nodeEq(n1)) = G(nodeEq(n2),nodeEq(n1)) - g;
                    end
                case 'W'
                    g = 1e9;
                    if nodeEq(n1)>0, G(nodeEq(n1),nodeEq(n1)) = G(nodeEq(n1),nodeEq(n1)) + g; end
                    if nodeEq(n2)>0, G(nodeEq(n2),nodeEq(n2)) = G(nodeEq(n2),nodeEq(n2)) + g; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        G(nodeEq(n1),nodeEq(n2)) = G(nodeEq(n1),nodeEq(n2)) - g;
                        G(nodeEq(n2),nodeEq(n1)) = G(nodeEq(n2),nodeEq(n1)) - g;
                    end
                case 'I'
                    Ival = br.value;
                    if nodeEq(n1)>0, Ivec(nodeEq(n1)) = Ivec(nodeEq(n1)) - Ival; end
                    if nodeEq(n2)>0, Ivec(nodeEq(n2)) = Ivec(nodeEq(n2)) + Ival; end
                case 'V'
                    vidx = vmap(bidx);
                    if nodeEq(n1)>0
                        G(vidx,nodeEq(n1)) = G(vidx,nodeEq(n1)) + 1;
                        G(nodeEq(n1),vidx) = G(nodeEq(n1),vidx) + 1;
                    end
                    if nodeEq(n2)>0
                        G(vidx,nodeEq(n2)) = G(vidx,nodeEq(n2)) - 1;
                        G(nodeEq(n2),vidx) = G(nodeEq(n2),vidx) - 1;
                    end
                    Ivec(vidx) = br.value;
                case 'C'
                    % ignored in DC
                case 'L'
                    g = 1e9;
                    if nodeEq(n1)>0, G(nodeEq(n1),nodeEq(n1)) = G(nodeEq(n1),nodeEq(n1)) + g; end
                    if nodeEq(n2)>0, G(nodeEq(n2),nodeEq(n2)) = G(nodeEq(n2),nodeEq(n2)) + g; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        G(nodeEq(n1),nodeEq(n2)) = G(nodeEq(n1),nodeEq(n2)) - g;
                        G(nodeEq(n2),nodeEq(n1)) = G(nodeEq(n2),nodeEq(n1)) - g;
                    end
            end
        end

        % Solve DC
        try
            x = G \ Ivec;
        catch ME
            warndlg({'System matrix is singular or ill-conditioned.'; ME.message}, ...
                'Simulation Warning');
            return;
        end

        %% ---- DC RESULTS: Vnodes + DC branch currents ----
        if strcmp(kind,'dc')
            Vnodes = zeros(Nnodes,1);
            for ni = 1:Nnodes
                if ni==groundNode, Vnodes(ni) = 0;
                else, Vnodes(ni) = x(nodeEq(ni)); end
            end

            % DC branch currents
            Ibranches = zeros(numel(branches),1);
            for bidx = 1:numel(branches)
                br = branches(bidx);
                n1 = br.n1; n2 = br.n2;
                v1 = (n1==groundNode)*0 + (n1~=groundNode)*Vnodes(n1);
                v2 = (n2==groundNode)*0 + (n2~=groundNode)*Vnodes(n2);
                switch br.type
                    case 'R'
                        Ibranches(bidx) = (v1 - v2) / br.value;
                    case 'W'
                        Ibranches(bidx) = 0;
                    case 'I'
                        Ibranches(bidx) = br.value;
                    case 'V'
                        if isKey(vmap,bidx)
                            Ibranches(bidx) = x(vmap(bidx));
                        else
                            Ibranches(bidx) = NaN;
                        end
                    otherwise
                        Ibranches(bidx) = NaN;
                end
            end

            S.simResult.kind      = 'dc';
            S.simResult.Vnodes    = Vnodes;
            S.simResult.nodes     = nodes;
            S.simResult.branches  = branches;
            S.simResult.Ibranches = Ibranches;
            setappdata(fig,'S',S);

            fprintf('=== DC operating point ===\n');
            for ni = 1:Nnodes
                fprintf('Node %d : %g V\n',ni,Vnodes(ni));
            end

            figure('Name','DC Node Voltages');
            plot(1:Nnodes,Vnodes,'-o'); xlabel('node index'); ylabel('V'); grid on;

            figure('Name','DC Branch Currents');
            bar(Ibranches);
            xlabel('branch index'); ylabel('Current (A)');
            grid on;

            return;
        end

        %% ---- TRANSIENT (with branch currents) ----
        answ = inputdlg({'Time step dt (s)','Stop time tstop (s)'}, ...
                        'Transient',1,{'1e-5','0.01'});
        if isempty(answ), return; end
        dt    = str2double(answ{1});
        tstop = str2double(answ{2});
        if isnan(dt) || dt<=0 || isnan(tstop) || tstop<=0
            errordlg('Invalid dt or tstop','Transient'); return;
        end
        nsteps = ceil(tstop/dt);
        times  = (0:nsteps)*dt;

        Gbase = zeros(nvar); Cmat = zeros(nvar); Isrc = zeros(nvar,1);
        Lbranches = [];
        for bidx = 1:numel(branches)
            br = branches(bidx); n1 = br.n1; n2 = br.n2;
            switch br.type
                case 'R'
                    g = 1.0 / br.value;
                    if nodeEq(n1)>0, Gbase(nodeEq(n1),nodeEq(n1)) = Gbase(nodeEq(n1),nodeEq(n1)) + g; end
                    if nodeEq(n2)>0, Gbase(nodeEq(n2),nodeEq(n2)) = Gbase(nodeEq(n2),nodeEq(n2)) + g; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        Gbase(nodeEq(n1),nodeEq(n2)) = Gbase(nodeEq(n1),nodeEq(n2)) - g;
                        Gbase(nodeEq(n2),nodeEq(n1)) = Gbase(nodeEq(n2),nodeEq(n1)) - g;
                    end
                case 'W'
                    g = 1e9;
                    if nodeEq(n1)>0, Gbase(nodeEq(n1),nodeEq(n1)) = Gbase(nodeEq(n1),nodeEq(n1)) + g; end
                    if nodeEq(n2)>0, Gbase(nodeEq(n2),nodeEq(n2)) = Gbase(nodeEq(n2),nodeEq(n2)) + g; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        Gbase(nodeEq(n1),nodeEq(n2)) = Gbase(nodeEq(n1),nodeEq(n2)) - g;
                        Gbase(nodeEq(n2),nodeEq(n1)) = Gbase(nodeEq(n2),nodeEq(n1)) - g;
                    end
                case 'I'
                    Ival = br.value;
                    if nodeEq(n1)>0, Isrc(nodeEq(n1)) = Isrc(nodeEq(n1)) - Ival; end
                    if nodeEq(n2)>0, Isrc(nodeEq(n2)) = Isrc(nodeEq(n2)) + Ival; end
                case 'V'
                    vidx = vmap(bidx);
                    if nodeEq(n1)>0, Gbase(vidx,nodeEq(n1)) = Gbase(vidx,nodeEq(n1)) + 1; Gbase(nodeEq(n1),vidx) = Gbase(nodeEq(n1),vidx) + 1; end
                    if nodeEq(n2)>0, Gbase(vidx,nodeEq(n2)) = Gbase(vidx,nodeEq(n2)) - 1; Gbase(nodeEq(n2),vidx) = Gbase(nodeEq(n2),vidx) - 1; end
                    Isrc(vidx) = br.value;
                case 'C'
                    Cval = br.value;
                    if nodeEq(n1)>0, Cmat(nodeEq(n1),nodeEq(n1)) = Cmat(nodeEq(n1),nodeEq(n1)) + Cval; end
                    if nodeEq(n2)>0, Cmat(nodeEq(n2),nodeEq(n2)) = Cmat(nodeEq(n2),nodeEq(n2)) + Cval; end
                    if nodeEq(n1)>0 && nodeEq(n2)>0
                        Cmat(nodeEq(n1),nodeEq(n2)) = Cmat(nodeEq(n1),nodeEq(n2)) - Cval;
                        Cmat(nodeEq(n2),nodeEq(n1)) = Cmat(nodeEq(n2),nodeEq(n1)) - Cval;
                    end
                case 'L'
                    Lbranches(end+1) = bidx;
            end
        end



        % Start transient from all-zero initial voltages (capacitors uncharged)
        x0 = zeros(nvar,1);
        x_prev = x0;


        





        % initial node voltages at t=0
        Vnodes_prev = zeros(Nnodes,1);
        for ni = 1:Nnodes
            if ni==groundNode, Vnodes_prev(ni)=0;
            else, Vnodes_prev(ni)=x_prev(nodeEq(ni)); end
        end

        Vnode_traj = zeros(Nnodes,nsteps+1);
        Vnode_traj(:,1) = Vnodes_prev;

        % inductor states (currents)
        Lstate = containers.Map('KeyType','double','ValueType','double');
        for lb = Lbranches
            Lstate(lb) = 0;
        end

        % store branch currents over time
        nBranches = numel(branches);
        Ibranch_traj = zeros(nBranches, nsteps+1);

        % initial branch currents (t=0)
        for bidx = 1:nBranches
            br = branches(bidx);
            n1 = br.n1; n2 = br.n2;
            v1 = (n1==groundNode)*0 + (n1~=groundNode)*Vnodes_prev(n1);
            v2 = (n2==groundNode)*0 + (n2~=groundNode)*Vnodes_prev(n2);
            switch br.type
                case 'R'
                    Ibranch_traj(bidx,1) = (v1 - v2)/br.value;
                case 'W'
                    Ibranch_traj(bidx,1) = 0;
                case 'I'
                    Ibranch_traj(bidx,1) = br.value;
                case 'V'
                    if isKey(vmap,bidx)
                        Ibranch_traj(bidx,1) = x_prev(vmap(bidx));
                    else
                        Ibranch_traj(bidx,1) = NaN;
                    end
                case 'C'
                    Ibranch_traj(bidx,1) = 0; % assume no initial current
                case 'L'
                    Ibranch_traj(bidx,1) = 0; % initial inductor current 0
            end
        end

        % time-stepping
        for step = 1:nsteps
            A   = Gbase + (Cmat/dt);
            rhs = Isrc  + (Cmat/dt)*x_prev;

            % stamp inductors (companion)
            for Lb = Lbranches
                br   = branches(Lb);
                Lval = br.value;
                if Lval <= 0, error('Inductor with nonpositive L'); end
                G_L  = dt / Lval;
                n1   = br.n1; n2 = br.n2;

                if nodeEq(n1)>0, A(nodeEq(n1),nodeEq(n1)) = A(nodeEq(n1),nodeEq(n1)) + G_L; end
                if nodeEq(n2)>0, A(nodeEq(n2),nodeEq(n2)) = A(nodeEq(n2),nodeEq(n2)) + G_L; end
                if nodeEq(n1)>0 && nodeEq(n2)>0
                    A(nodeEq(n1),nodeEq(n2)) = A(nodeEq(n1),nodeEq(n2)) - G_L;
                    A(nodeEq(n2),nodeEq(n1)) = A(nodeEq(n2),nodeEq(n1)) - G_L;
                end

                i_prev = Lstate(Lb);
                if nodeEq(n1)>0, rhs(nodeEq(n1)) = rhs(nodeEq(n1)) - i_prev; end
                if nodeEq(n2)>0, rhs(nodeEq(n2)) = rhs(nodeEq(n2)) + i_prev; end
            end

            x_new = A \ rhs;

            % new node voltages
            Vnodes_new = zeros(Nnodes,1);
            for ni = 1:Nnodes
                if ni==groundNode, Vnodes_new(ni)=0;
                else, Vnodes_new(ni)=x_new(nodeEq(ni)); end
            end

            % update inductor currents and store in Lstate
            for Lb = Lbranches
                br = branches(Lb);
                n1 = br.n1; n2 = br.n2;
                v1 = (n1==groundNode)*0 + (n1~=groundNode)*Vnodes_new(n1);
                v2 = (n2==groundNode)*0 + (n2~=groundNode)*Vnodes_new(n2);
                G_L = dt / br.value;
                i_prev = Lstate(Lb);
                i_new  = G_L*(v1 - v2) + i_prev;
                Lstate(Lb) = i_new;
            end

            % compute branch currents at this time step
            for bidx = 1:nBranches
                br = branches(bidx);
                n1 = br.n1; n2 = br.n2;
                v1_new = (n1==groundNode)*0 + (n1~=groundNode)*Vnodes_new(n1);
                v2_new = (n2==groundNode)*0 + (n2~=groundNode)*Vnodes_new(n2);
                v1_prev = (n1==groundNode)*0 + (n1~=groundNode)*Vnodes_prev(n1);
                v2_prev = (n2==groundNode)*0 + (n2~=groundNode)*Vnodes_prev(n2);
                switch br.type
                    case 'R'
                        Ibranch_traj(bidx,step+1) = (v1_new - v2_new)/br.value;
                    case 'W'
                        Ibranch_traj(bidx,step+1) = 0;
                    case 'I'
                        Ibranch_traj(bidx,step+1) = br.value;
                    case 'V'
                        if isKey(vmap,bidx)
                            Ibranch_traj(bidx,step+1) = x_new(vmap(bidx));
                        else
                            Ibranch_traj(bidx,step+1) = NaN;
                        end
                    case 'C'
                        dv = (v1_new - v2_new) - (v1_prev - v2_prev);
                        Ibranch_traj(bidx,step+1) = br.value * dv / dt;
                    case 'L'
                        Ibranch_traj(bidx,step+1) = Lstate(bidx);
                end
            end

            Vnode_traj(:,step+1) = Vnodes_new;
            x_prev      = x_new;
            Vnodes_prev = Vnodes_new;
        end

        S.simResult.kind         = 'tran';
        S.simResult.times        = times;
        S.simResult.Vnodes       = Vnode_traj;
        S.simResult.nodes        = nodes;
        S.simResult.branches     = branches;
        S.simResult.Ibranch_traj = Ibranch_traj;
        setappdata(fig,'S',S);

        figure('Name','Transient Node Voltages'); hold on; grid on;
        for ni = 1:Nnodes
            if ni==groundNode, continue; end
            plot(times,Vnode_traj(ni,:), 'DisplayName',sprintf('node%d',ni));
        end
        legend('show'); xlabel('time (s)'); ylabel('voltage (V)');
    end

%% Probing helpers
    function probeNode(coord)
        S = getappdata(fig,'S');
        if isempty(S.simResult)
            warndlg('Run a simulation first.','Probe'); return;
        end
        nodes = S.simResult.nodes;
        d = sqrt((nodes(:,1)-coord(1)).^2 + (nodes(:,2)-coord(2)).^2);
        [~, ni] = min(d);
        if strcmp(S.simResult.kind,'dc')
            V = S.simResult.Vnodes(ni);
            msgbox(sprintf('Node %d: %g V (DC)',ni,V),'Probe');
        else
            times = S.simResult.times;
            Vt    = S.simResult.Vnodes(ni,:);
            figure('Name',sprintf('Probe: node %d',ni));
            plot(times,Vt); xlabel('time (s)'); ylabel('V'); grid on;
        end
    end

    function probeBranch(idx)
        S = getappdata(fig,'S');
        if isempty(S) || ~isfield(S,'simResult') || isempty(S.simResult)
            warndlg('No simulation results available. Run a simulation first.','Probe');
            return;
        end
        branches = S.simResult.branches;
        if idx < 1 || idx > numel(branches)
            warndlg('Branch index out of range.','Probe');
            return;
        end
        br = branches(idx);
        n1 = br.n1; n2 = br.n2;

        if strcmp(S.simResult.kind,'dc')
            Vn = S.simResult.Vnodes;
            v = Vn(n1) - Vn(n2);
            if isfield(S.simResult,'Ibranches')
                Ibranches = S.simResult.Ibranches;
                i = Ibranches(idx);
                msg = sprintf('%s: v = %g V, i = %g A (DC)',br.name,v,i);
            else
                msg = sprintf('%s: v = %g V (DC)',br.name,v);
            end
            msgbox(msg,'Probe');
            return;
        end

        % Transient: show both v(t) and i(t) if available
        times  = S.simResult.times;
        Vt     = S.simResult.Vnodes;
        vtrace = Vt(n1,:) - Vt(n2,:);

        figure('Name',sprintf('Probe branch %s',br.name));
        if isfield(S.simResult,'Ibranch_traj')
            itrace = S.simResult.Ibranch_traj(idx,:);
            subplot(2,1,1);
            plot(times,vtrace); ylabel('V'); grid on;
            title(sprintf('Branch %s voltage',br.name));
            subplot(2,1,2);
            plot(times,itrace); ylabel('I (A)'); xlabel('time (s)'); grid on;
            title(sprintf('Branch %s current',br.name));
        else
            plot(times,vtrace); xlabel('time (s)'); ylabel('V'); grid on;
            title(sprintf('Branch %s voltage',br.name));
        end
    end

%% Netlist & save/load
    function printNetlist()
        S = getappdata(fig,'S');
        for k=1:numel(S.components)
            c = S.components{k};
            fprintf('%s %s -> %s : %g\n', ...
                c.name, mat2str(c.p1,3), mat2str(c.p2,3), c.value);
        end
        for w=1:numel(S.wires)
            fprintf('Wire %d: %s\n', w, mat2str(S.wires{w}.pts,3));
        end
    end

    function saveProject()
        S = getappdata(fig,'S');
        [f,p] = uiputfile('*.mat','Save project as');
        if isequal(f,0), return; end
        fname = fullfile(p,f);
        components  = S.components;
        wires       = S.wires;
        groundCoord = S.groundCoord;
        save(fname,'components','wires','groundCoord');
        S.projectFile = fname;
        setappdata(fig,'S',S);
        msgbox('Project saved','Save');
    end

    function loadProject()
        [f,p] = uigetfile('*.mat','Load project file');
        if isequal(f,0), return; end
        fname = fullfile(p,f);
        D = load(fname);
        S = getappdata(fig,'S');
        clearCanvas();
        S.components   = D.components;
        S.wires        = D.wires;
        S.groundCoord  = D.groundCoord;

        for k=1:numel(S.components)
            c = S.components{k};
            hLine = line(ax,[c.p1(1) c.p2(1)],[c.p1(2) c.p2(2)], ...
                'LineWidth',3,'Color',[1 1 1]);
            hTxt  = text(ax,(c.p1(1)+c.p2(1))/2,(c.p1(2)+c.p2(2))/2, ...
                sprintf('%s\n%g',c.type,c.value), ...
                'HorizontalAlignment','center','Color',[1 1 1]);
            S.components{k}.handles = [hLine hTxt];
        end
        for w=1:numel(S.wires)
            pts = S.wires{w}.pts;
            h = line(ax,pts(:,1),pts(:,2),'Color',[1 1 1]);
            S.wires{w}.handle = h;
        end
        if ~isempty(S.groundCoord), plotGround(S.groundCoord); end
        setappdata(fig,'S',S);
    end

    function clearAll()
        clearCanvas();
        S = getappdata(fig,'S');
        S.components = {};
        S.wires      = {};
        S.groundCoord = [];
        S.simResult   = [];
        setappdata(fig,'S',S);
    end

    function clearCanvas()
        cla(ax);
        drawGrid();
        h = findobj(ax,'Tag','groundMarker');
        if ~isempty(h), delete(h); end
    end

%% Merge endpoints helper
    function [nodes, idxmap] = mergePoints(pts, tol)
        nodes = [];
        idxmap = zeros(size(pts,1),1);
        for i = 1:size(pts,1)
            p = pts(i,:);
            if isempty(nodes)
                nodes = p; idxmap(i) = 1;
            else
                d = sqrt((nodes(:,1)-p(1)).^2 + (nodes(:,2)-p(2)).^2);
                [mn,ii] = min(d);
                if mn <= tol
                    idxmap(i) = ii;
                else
                    nodes = [nodes; p];
                    idxmap(i) = size(nodes,1);
                end
            end
        end
    end

end
